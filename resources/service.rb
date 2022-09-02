#
# Cookbook:: filebeat
# Resource:: filebeat_service
#

resource_name :filebeat_service
provides :filebeat_service

property :service_name, String, default: 'filebeat'
property :filebeat_install_resource_name, String, default: 'default'
property :disable_service, [true, false], default: false
property :purge_prospectors_dir, [true, false], default: false

property :service_ignore_failure, [true, false], default: false
property :service_retries, Integer, default: 2
property :service_retry_delay, Integer, default: 0

default_action :create

action :create do
  install_preview_resource = check_beat_resource(Chef.run_context, :filebeat_install_preview, new_resource.filebeat_install_resource_name)
  install_resource = check_beat_resource(Chef.run_context, :filebeat_install, new_resource.filebeat_install_resource_name)
  filebeat_install_resource = install_preview_resource || install_resource
  raise "could not find resource filebeat_install[#{new_resource.filebeat_install_resource_name}] or filebeat_install_preview[#{new_resource.filebeat_install_resource_name}]" if filebeat_install_resource.nil?

  ruby_block 'delay run purge prospectors dir' do
    block do
    end
    notifies :run, 'ruby_block[purge_prospectors_dir]'
  end

  with_run_context(:root) do
    ruby_block 'purge_prospectors_dir' do
      block do
        purge_prospectors_config(filebeat_install_resource.prospectors_dir)
      end
      only_if { new_resource.purge_prospectors_dir }
      action :nothing
    end
  end

  ruby_block 'delay filebeat service start' do
    block do
    end
    notifies :start, "service[#{new_resource.service_name}]"
    not_if { new_resource.disable_service }
  end

  service_action = new_resource.disable_service ? %i(disable stop) : %i(enable)

  service new_resource.service_name do
    provider Chef::Provider::Service::Solaris if platform_family?('solaris2')
    retries new_resource.service_retries
    retry_delay new_resource.service_retry_delay
    supports :status => true, :restart => true
    action service_action
    ignore_failure new_resource.service_ignore_failure
  end
end

action :delete do
end

action_class do
  include ::Filebeat::Helpers
end
