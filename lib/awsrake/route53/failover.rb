module AWSRake
  class Route53
    class Failover < AWSRake::Route53

      NAME = 'failover'

      TYPE = {
        primary: 'PRIMARY',
        secondary: 'SECONDARY'
      }

      DNS_TYPE = select_dns_type(:a, :aaaa, :cname, :txt)

      ENV_CONFIG = {
        file: 'AWSRAKE_CONFIG_FAILOVER_FILE',
        var: 'AWSRAKE_CONFIG_FAILOVER'
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
        run_action(name, type) do |b_action|
          message "\n#{name.to_s.capitalize.chop}ing #{NAME} #{type.upcase}..."

          action_status(@r53.change_resource_record_sets(b_action).change_info.id) do |info|
            message "Submitted time: #{info.submitted_at}"
            message "Comment: #{info.comment}"
          end
        end
      end

      def action_all(name)
        TYPE.keys.each do |type|
          action(name, type)
        end
      end

      private

      def action_status(change_id,
                        a_status = CHANGE_INFO_STATUS[:pending],
                        info = nil)
        change_id = File.basename(change_id)

        while a_status == CHANGE_INFO_STATUS[:pending]
          sleep 5
          info = @r53.get_change(id: change_id).change_info

          message "    ...status: #{info.status}"

          a_status = info.status
        end
        yield(info)
      end

      def run_action(name, type)
        yield(build_action(ACTION[name], TYPE[type], @data[:data][type]))
      end

      def build_action(type, f_type, f_data)
p build_changes(type, f_type, f_data)
        {
          hosted_zone_id: @hosted_zone_id,
          change_batch: {
            comment: "#{self.class} #{ACTION.key(type)}d #{f_type} for '#{full_dns_name}(#{@data[:dns_type]})'",
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
              type: @data[:dns_type],
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
        if data[:alias]
          target[:alias_target] = {
            hosted_zone_id: alias_zone_id(data[:alias]),
            dns_name: full_dns_name(data[:alias][:dns_name]),
            evaluate_target_health: data[:alias][:evaluate_target_health]
          }
        #TODO: create full support
        elsif data[:resource_records]
          target[:ttl] = data[:ttl]
          target[:resource_records] = data[:resource_records]
        else
          nil
        end
      end

      def set_identifier(data, type, id = 0)
        id = nil if id == 0
        data[:set_identifier] || "#{@data[:dns_name]}-#{type}#{id}"
      end

    end
  end
end
