module AWSRake
  class Route53
    class Failover < AWSRake::Route53

      NAME = 'failover'

      TYPE = {
        primary: 'PRIMARY',
        secondary: 'SECONDARY'
      }

      KEY = {
        primary: TYPE[:primary].downcase,
        secondary: TYPE[:secondary].downcase
      }

      DNS_TYPE = {
        a: 'A',
        aaaa: 'AAAA',
        cname: 'CNAME'
      }

      def dns_type_primary?
        if dns_type_defined?
          @dns_name_objs.each do |i|
            return true if i.failover == TYPE[:primary]
          end
        end
        false
      end

      def dns_type_primary
        if dns_type_defined?
          @dns_name_objs.each do |i|
            return i if i.failover == TYPE[:primary]
          end
        end
        nil
      end

      def dns_type_secondary?
        if dns_type_defined?
          @dns_name_objs.each do |i|
            return true if i.failover == TYPE[:secondary]
          end
        end
        false
      end

      def dns_type_failover?
        dns_type_defined? && dns_type_primary? && dns_type_secondary?
      end

      def action(name, type)
        res = @r53.change_resource_record_sets(build_action(ACTION[name],
                                               TYPE[type],
                                               @data[KEY[type]]))
        message "ID: #{res.change_info.id}"
        message "Status: #{res.change_info.status}"
        sleep 3
        message "Status: #{res.change_info.status}"
        message "Submitted time: #{res.change_info.submitted_at}"
        message "Comment: #{res.change_info.comment}"

        res = nil
      end

      def action_all(name)
        TYPE.keys.each do |type|
          action(name, type)
        end
      end

      private

      def build_action(type, f_type, f_data)
p build_changes(type, f_type, f_data)
        {
          hosted_zone_id: @hosted_zone_id,
          change_batch: {
            comment: "#{self.class} #{type}d '#{@dns_name}'",
            changes: build_changes(type, f_type, f_data)
          }
        }
      end

      def build_changes(type, f_type, f_data, array = [])
        ((f_data.kind_of?(Array))?(f_data):([f_data])).each do |i_data|
          array << {
            action: type,
            resource_record_set: {
              name: full_dns_name,
              type: @dns_type,
              set_identifier: set_identifier(i_data, f_type, array.size),
              failover: f_type#,
              #health_check_id: nil,
              #traffic_policy_instance_id: nil,
            }
          }
          set_target(array.last[:resource_record_set], i_data)
        end
        return array
      end

      def set_target(target, data)
        if data['alias']
          target[:alias_target] = {
            hosted_zone_id: elb_zone_id(data['alias']['dns_name']),
#            hosted_zone_id: @hosted_zone_id,
            dns_name: full_dns_name(data['alias']['dns_name']),
            evaluate_target_health: data['alias']['evaluate_target_health']
          }
        #TODO: create full support
        elsif data['resource_records']
          target[:ttl] = data['ttl']
          target[:resource_records] = data['resource_records']
        else
          nil
        end
      end

      def set_identifier(data, type, id = nil)
        data['set_identifier'] || "#{@dns_name}-#{type}#{id}"
      end

    end
  end
end
