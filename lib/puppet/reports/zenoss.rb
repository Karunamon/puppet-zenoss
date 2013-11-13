#
# puppet report processor for zenoss, using xmlrpc. 
# modeled after James Turnbull's processor for Zendesk
# and his other processors at https://github.com/jamtur01/
#
# Modified from Don Johnson's version at
# https://github.com/donjohnson/puppet-zenoss to support 
# Zenoss v4 and fix a couple of small corner cases
#
require 'puppet'
require 'yaml'
require 'pp'

begin
  require "xmlrpc/client"
rescue LoadError => e
  Puppet.info "You need the `xmlrpc/client` library to use the zenoss report"
end

Puppet::Reports.register_report(:zenoss) do

  configfile = File.join([File.dirname(Puppet.settings[:config]), "zenoss.yaml"])
  raise(Puppet::ParseError, "zenoss4puppet config file #{configfile} not readable") unless File.exist?(configfile)
  config = YAML.load_file(configfile)
  ZENOSS_USER        = config[:zenoss_user]
  ZENOSS_PASS        = config[:zenoss_pass]
  ZENOSS_SERVER      = config[:zenoss_server]
  ZENOSS_XMLRPC_PORT = config[:zenoss_xmlrpc_port]
  ZENOSS_EVENTCLASS  = config[:zenoss_eventclass]
  ZENOSS_COMPONENT   = config[:zenoss_component]


  desc <<-DESC
  Send notification of failed reports to Zenoss and open new tickets.
  DESC


  def process
    if self.status == 'failed'
      Puppet.debug "Creating Zenoss event for failed run on #{self.host}."
      event = {}
      output = []
      self.logs.each do |log|
        output << log
      end
      #The new2 method breaks if our password contains certain special characters. Let's use regular new for compatibility..
      server = XMLRPC::Client.new(ZENOSS_SERVER, "/zport/dmd/ZenEventManager", ZENOSS_XMLRPC_PORT, nil, nil, ZENOSS_USER, ZENOSS_PASS)
      event = {'device' => "#{self.host}", 
               'component' => "#{ZENOSS_COMPONENT}",
               'eventclass' => "#{ZENOSS_EVENTCLASS}", 
               'severity' => 2, 
               'summary' => "Puppet run for #{self.host} failed at #{Time.now.asctime} : #{output.join("\n")}" }
      ok, param = server.call2('sendEvent', event) 
      Puppet.err "Error sending Zenoss event: #{param}" unless ok
    end
  end
end
