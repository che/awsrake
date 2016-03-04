require 'json'


module AWSRake
  class Route53
    attr_reader :data

    DNS_TYPE = {
      a: 'A',
      aaaa: 'AAAA',
      cname: 'CNAME',
      txt: 'TXT',
      ns: 'NS',
      mx: 'MX',
      ptr: 'PTR',
      srv: 'SRV',
      spf: 'SPF',
      soa: 'SOA'
    }

    ACTION = {
      create: 'CREATE',
      update: 'UPSERT',
      delete: 'DELETE'
    }

    CHANGE_INFO_STATUS = {
      insync: 'INSYNC',
      pending: 'PENDING'
    }

    DNS_FULL_NAME_EXT = '.'

    def self.select_dns_type(*keys)
      DNS_TYPE.select { |k, v| keys.include?(k) }
    end

    def initialize(options = {})
      @config_file = (options[:config_file] || ENV[self.class::ENV_CONFIG[:file]])
      @config_init = !!options[:config_init]
      @message_status = !!options[:message]
      @hosted_zone_obj = nil
      @hosted_zone_id = nil
      @data = nil
      @r53 = Aws::Route53::Client.new
      @config_file = File.expand_path(@config_file) if config_file?
      init_config if @config_init
    end

    def message?
      @message_status
    end

    def message(str)
      STDOUT.puts(str) if @message_status
    end

    def config_file?(cfile = @config_file)
      !!cfile
    end

    def real_config_file?(cfile = @config_file)
      config_file?(cfile) && File.exists?(cfile) && File.file?(cfile)
    end

    def init_config(cfile = @config_file)
      @data = JSON.parse(init_config_data(cfile), {symbolize_names: true}).freeze
p @data
    end

    def hosted_zone?(zone = @data[:hosted_zone])
      zone && zone.kind_of?(String) && !zone.strip.empty?
    end

    def real_hosted_zone?(zone = @data[:hosted_zone])
      define_hosted_zone(zone) do |status|
        if status 
          message "Hosted zone '#{zone}' exists"
        else
          message "Hosted zone '#{zone}' doesn't exist"
        end
        return status
      end
      false
    end

    def hosted_zone_defined?
      !!@hosted_zone_obj
    end

    def dns_name?(name = @data[:dns_name])
      name && name.kind_of?(String) && !name.strip.empty?
    end

    def real_dns_name?(name = @data[:dns_name],
                       zone = @data[:hosted_zone])
      if real_hosted_zone?(zone) 
        define_dns_name(name, zone) do |status|
          if status
            message "DNS name '#{name}' exists"
          else
            message "DNS name '#{name}' doesn't exist"
          end
          return status
        end
      end
      false
    end

    def dns_name_defined?
      hosted_zone_defined? && !!@dns_name_objs && !@dns_name_objs.empty?
    end

    def dns_type?(type = @data[:dns_type])
      type && type.kind_of?(String) && self.class::DNS_TYPE.values.include?(type)
    end

    def real_dns_type?(type = @data[:dns_type],
                       name = @data[:dns_name],
                       zone = @data[:hosted_zone])
      if real_dns_name?(name, zone)
        define_dns_type(type, name, zone) do |status|
          if status
            message "DNS type '#{type}' exists"
          else
            message "DNS type '#{type}' doesn't exist"
         end
          return status
        end
      end
      false
    end

    def dns_type_defined?
      dns_name_defined? && !!@dns_type_objs
    end

    def full_dns_name(name = @data[:dns_name],
                      zone = @data[:hosted_zone])
      (name[-1] == DNS_FULL_NAME_EXT)?(name):("#{name}.#{zone}")
    end

    def full_elb_dns_name(name)
      "dualstack.#{name}.".downcase
    end

    def alias_zone_id(alias_data)
      if !!alias_data[AWSRake::ElasticLoadBalancing::NAME.to_sym]
        define_alias_ebl_data(alias_data[AWSRake::ElasticLoadBalancing::NAME.to_sym]) do |ebl_data|
          alias_data[:dns_name] = full_elb_dns_name(ebl_data.canonical_hosted_zone_name)
          ebl_data.canonical_hosted_zone_name_id
        end
      else
         @hosted_zone_id
      end
    end

    private

    def init_config_data(cfile = @config_file)
      if real_config_file?(cfile)
        File.read(cfile)
      else
        ENV[self.class::ENV_CONFIG[:var]]
      end
    end

    def define_alias_ebl_data(ebl_data)
      yield(AWSRake::ElasticLoadBalancing.new(region: ebl_data[:region],
                                              name: ebl_data[:name]).describe)
    end

    def find_hosted_zone(zone = @data[:hosted_zone])
      @r53.list_hosted_zones.hosted_zones.each do |i|
        if i.name == zone
          @hosted_zone_obj = i
          @hosted_zone_id = File.basename(@hosted_zone_obj.id)
          break
        end
      end
    end

    def define_hosted_zone(zone = @data[:hosted_zone])
      find_hosted_zone(zone) if hosted_zone?(zone)
      yield(hosted_zone_defined?) if block_given?
    end

    def find_dns_name(name = @data[:dns_name],
                      zone = @data[:hosted_zone])
      @r53.list_resource_record_sets(max_items: @hosted_zone_obj.resource_record_set_count,
                                     start_record_name: full_dns_name(name, zone),
                                     hosted_zone_id: @hosted_zone_id).resource_record_sets
    end

    # HOOK for *.domain.com
    def check_dns_name(full_dns_name)
      @dns_name_objs.delete_if do |i|
        i.name != full_dns_name
      end
    end

    def define_dns_name(name = @data[:dns_name],
                        zone = @data[:hosted_zone])
      if dns_name?(name) && hosted_zone_defined? && !@dns_name_objs
        @dns_name_objs = find_dns_name(name, zone)
        check_dns_name(full_dns_name(name, zone))
      end
      yield(hosted_zone_defined? && dns_name_defined?) if block_given?
    end

    def define_dns_type(type = @data[:dns_type],
                        name = @data[:dns_name],
                        zone = @data[:hosted_zone])
      if dns_type?(type) && hosted_zone_defined? && dns_name_defined?
        @dns_name_objs.each do |i|
          if i.type == type
            @dns_type_objs = true
            (block_given?)?(yield(true)):(return true)
          end
        end
      end
      @dns_type_objs = false
      (block_given?)?(yield(false)):(false)
    end

  end
end
