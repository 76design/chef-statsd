include_recipe "git"
include_recipe "nodejs"
include_recipe "runit"

git node["statsd"]["dir"] do
  repository node["statsd"]["repository"]
  reference node["statsd"]["reference"]
  action :sync
  notifies :restart, "runit_service[statsd]"
end

directory node["statsd"]["conf_dir"] do
  action :create
end

graphite_host = node['statsd']['graphite_host']

unless Chef::Config[:solo]
  graphite_results = search(:node, node['statsd']['graphite_query'])

  unless graphite_results.empty?
    graphite_host = graphite_results[0]['ipaddress']
  end
end

template "#{node["statsd"]["conf_dir"]}/config.js" do
  mode "0644"
  source "config.js.erb"

  config_hash = {
    :address           => node["statsd"]["address"],
    :port              => node["statsd"]["port"],
    :flushInterval     => node["statsd"]["flush_interval"],
    :percentThreshold  => node["statsd"]["percent_threshold"],
    :graphitePort      => node["statsd"]["graphite_port"],
    :graphiteHost      => graphite_host,
    :deleteIdleStats   => node["statsd"]["delete_idle_stats"],
    :deleteGauges      => node["statsd"]["delete_gauges"],
    :deleteTimers      => node["statsd"]["delete_timers"],
    :deleteSets        => node["statsd"]["delete_sets"],
    :deleteCounters    => node["statsd"]["delete_counters"],
    
    :graphite => {
      :legacyNamespace   => node["statsd"]["graphite"]["legacy_namespace"],
      :globalPrefix      => node["statsd"]["graphite"]["global_prefix"],
      :prefixCounter     => node["statsd"]["graphite"]["prefix_counter"],
      :prefixTimer       => node["statsd"]["graphite"]["prefix_timer"],
      :prefixGauge       => node["statsd"]["graphite"]["prefix_gauge"],
      :prefixSet         => node["statsd"]["graphite"]["prefix_set"]
    }
  }.merge(node[:statsd][:extra_config])

  variables(:config_hash => config_hash)
  
  notifies :restart, "runit_service[statsd]"
end

user node["statsd"]["username"] do
  system true
  shell "/bin/false"
end

runit_service "statsd" do
  action [:enable, :start]
  default_logger true
  options ({
    :user => node['statsd']['username'],
    :statsd_dir => node['statsd']['dir'],
    :conf_dir => node['statsd']['conf_dir']
  })
end
