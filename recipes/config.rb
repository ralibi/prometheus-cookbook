tls_dir = node['prometheus']['tls_certs_dir']

# Copy configuration from different repository
git "#{node["prometheus"]["dir"]}/#{node["prometheus"]["runbooks"]["repo_name"]}" do
  repository node["prometheus"]["runbooks"]["repo_url"]
  revision node["prometheus"]["runbooks"]["branch"]
  action :sync
  notifies :restart, "service[prometheus]", :delayed
end

link node["prometheus"]["config"]["rules_dir"] do
  to "#{node["prometheus"]["dir"]}/#{node["prometheus"]["runbooks"]["repo_name"]}/#{node["prometheus"]["runbooks"]["dir"]}/rules"
  owner node["prometheus"]["user"]
  group node["prometheus"]["group"]
end

link node["prometheus"]["config"]["alerting_rules_dir"] do
  to "#{node["prometheus"]["dir"]}/#{node["prometheus"]["runbooks"]["repo_name"]}/#{node["prometheus"]["runbooks"]["dir"]}/alerts"
  owner node["prometheus"]["user"]
  group node["prometheus"]["group"]
end

link node["prometheus"]["config"]["recording_rules_dir"] do
  to "#{node["prometheus"]["dir"]}/#{node["prometheus"]["runbooks"]["repo_name"]}/#{node["prometheus"]["runbooks"]["dir"]}/recordings"
  owner node["prometheus"]["user"]
  group node["prometheus"]["group"]
end

directory node["prometheus"]["config"]["inventory_dir"] do
  owner node["prometheus"]["user"]
  group node["prometheus"]["group"]
  mode "0755"
  recursive true
end

if node["prometheus"]["tls_certs"]["enabled"]

  directory node["prometheus"]["tls_certs_dir"] do
    owner node["prometheus"]["user"]
    group node["prometheus"]["group"]
    mode "0755"
    recursive true
  end

  file "#{tls_dir}/ca.crt" do
    owner node["prometheus"]["user"]
    group node["prometheus"]["group"]
    mode "0644"
    content node["prometheus"]["tls_certs"]["ca_content"]
  end

  file "#{tls_dir}/client.crt" do
    owner node["prometheus"]["user"]
    group node["prometheus"]["group"]
    mode "0644"
    content node["prometheus"]["tls_certs"]["cert_content"]
  end

  file "#{tls_dir}/client.key" do
    owner node["prometheus"]["user"]
    group node["prometheus"]["group"]
    mode "0644"
    content node["prometheus"]["tls_certs"]["key_content"]
  end

  node["prometheus"]["config"]["remote_write"].each do |config|
    node.default["#{config}"]["ca_file"] = "#{tls_dir}/ca.crt"
    node.default["#{config}"]["cert_file"] = "#{tls_dir}/client.crt"
    node.default["#{config}"]["key_file"] = "#{tls_dir}/client.key"
    node.default["#{config}"]["insecure_skip_verify"] = node["prometheus"]["tls_certs"]["insecure_skip_verify"]
  end

  node["prometheus"]["config"]["alerting"]["alertmanagers"].each do |config|
    node.default["#{config}"]["ca_file"] = "#{tls_dir}/ca.crt"
    node.default["#{config}"]["cert_file"] = "#{tls_dir}/client.crt"
    node.default["#{config}"]["key_file"] = "#{tls_dir}/client.key"
    node.default["#{config}"]["insecure_skip_verify"] = node["prometheus"]["tls_certs"]["insecure_skip_verify"]
  end
end

config = {
  "global" => {
    "scrape_interval" => node["prometheus"]["config"]["scrape_interval"],
    "scrape_timeout" => node["prometheus"]["config"]["scrape_timeout"],
    "evaluation_interval" => node["prometheus"]["config"]["evaluation_interval"],
    "external_labels" => node["prometheus"]["config"]["external_labels"],
  },
  "remote_write" => node["prometheus"]["config"]["remote_write"],
  "remote_read" => node["prometheus"]["config"]["remote_read"],
  "scrape_configs" => parse_jobs(node["prometheus"]["config"]["scrape_configs"], node["prometheus"]["config"]["inventory_dir"]),
  "alerting" => node["prometheus"]["config"]["alerting"],
  "rule_files" => node["prometheus"]["config"]["rule_files"],
}

file "Prometheus config" do
  path node["prometheus"]["flags"]["config.file"]
  content hash_to_yaml(config)
  owner node["prometheus"]["user"]
  group node["prometheus"]["group"]
  mode "0644"
  notifies :restart, "service[prometheus]"
end
