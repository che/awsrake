module AWSRake
  class ElasticLoadBalancing
    attr_reader :region

    NAME = 'elastic_load_balancing'

    REGION = {
      us_east_1: 'us-east-1',
      us_west_1: 'us-west-1',
      us_west_2: 'us-west-2',
      eu_west_1: 'eu-west-1',
      eu_central_1: 'eu-central-1',
      ap_northeast_1: 'ap-northeast-1',
      ap_northeast_2: 'ap-northeast-2',
      ap_southeast_1: 'ap-southeast-1',
      ap_southeast_2: 'ap-southeast-2',
      sa_east_1: 'sa-east-1'
    }

    def initialize(options = {})
      @region = options[:region]
      @name = options[:name]
      raise "Invalid region '#{@region}' for ElasticLoadBalancing" if !region?
      @elb = Aws::ElasticLoadBalancing::Client.new(region: @region)
    end

    def region?(reg = @region)
      REGION.values.include?(reg) 
    end

    def describe?(name = @name)
      !!@describe || describe(name)
    end

    def describe(name = @name)
      @describe = @elb.describe_load_balancers(load_balancer_names: [name]).load_balancer_descriptions.first
      @describe = nil if !@name
      @describe
    end

  end
end
