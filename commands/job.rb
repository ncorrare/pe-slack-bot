module PESlackBot
  module Commands
    class Job < SlackRubyBot::Commands::Base
      match(/^(?<bot>\w*)\sjob\s(?<verb>\w*)(\s|$)(?<noun>\w*)(\s|$)(?<argument>\w*)(\s|$)(?<mode>\w*)$/) do |client, data, match|
        if (Puppet.settings[:confdir]) then
          configfile = File.join([File.dirname(Puppet.settings[:confdir]), "peslackbot.yaml"])
        else
          configfile = "/etc/puppetlabs/puppet/peslackbot.yaml"
        end
        raise(ParseError, "PeSlackBot config file #{configfile} not readable") unless File.exist?(configfile)
        config = YAML.load_file(configfile)
        host = config['puppetdbhost']
        tokenfile = "#{ENV['HOME']}/.puppetlabs/token"
        raise(ParseError, "No orchestrator token found on #{tokenfile}") unless File.exist?(tokenfile)
        if token=File.read(tokenfile)
          orch = Net::HTTP.new(host, 8143)
          orch.use_ssl = true
          orch.verify_mode = OpenSSL::SSL::VERIFY_NONE
          #do whatever orchestration voodoo
          case match[:verb]
            when 'list'
              attachments = Array.new
              request = Net::HTTP::Get.new("/orchestrator/v1/jobs?limit=5")
              request.add_field("X-Authentication", token)
              response = orch.request(request)
              jobs = JSON.parse(response.body)
	      jobcount = jobs["items"].count
	      if match[:noun]=='limit'
	        i = jobcount - match[:argument].to_i
	      else
                if (jobcount - 5) > 0
                  i = jobcount - 5
                else
                  i = 0
                end
	      end
	      while i < jobcount do
	        job = jobs["items"][i]
              #for job in jobs["items"] do
                case job['state']
                  when 'running'
                    color = '#4683A6'
                  when 'stopped'
                    color = '#FFD801'
                  when 'finished'
                    color = '#82C045'
                  when 'failed'
                    color = '#AD2927'
                  else
                    color = '#FFFFFF'
                  end
                  if job['options']['noop']=='true'
                    mode='in noop mode'
                  end
                  attachments.push(
                    fallback: "Job #{job['name']} #{job['state']} on #{job['timestamp']} in #{job['environment']['name']} by #{job['owner']['login']} #{mode}",
                    title: "Job #{job['name']} by #{job['owner']['login']}",
                    text: "#{job['state']} on #{job['timestamp']} in #{job['environment']['name']} #{mode}",
                    color: color
              )
	      i += 1
	      end

              client.web_client.chat_postMessage(
                channel: data.channel,
                as_user: true,
                attachments: attachments
	      )
            when 'run'
              #run a particular job. Requires at least environment as noun and an optional application as argument and noop flag as mode 
            when 'show'
              attachments = Array.new
              request = Net::HTTP::Get.new("/orchestrator/v1/jobs/#{match[:noun]}/nodes")
              request.add_field("X-Authentication", token)
              response = orch.request(request)
              nodes = JSON.parse(response.body)
              nodecount = nodes["items"].count
              if match[:argument]=='limit'
                i = nodecount - match[:mode].to_i
              else
                if (nodecount - 5) > 0
                  i = nodecount - 5
                else
                  i = 0
              end
              end
              while (i < nodecount) do
                node = nodes["items"][i]
              #for job in jobs["items"] do
                case node['state']
                  when 'running'
                    color = '#4683A6'
                  when 'stopped'
                    color = '#FFD801'
                  when 'finished'
                    color = '#82C045'
                  when 'errored'
                    color = '#AD2927'
                  else
                    color = '#FFFFFF'
                  end
                  attachments.push(
                    fallback: "Node #{node['name']} #{node['state']} on #{node['timestamp']}",
                    title: "Node #{node['name']}",
                    text: "#{node['state']} on #{node['timestamp']}",
                    color: color
              )
              i += 1
              end
            client.web_client.chat_postMessage(
              channel: data.channel,
              as_user: true,
              attachments: attachments
            )
            client.say(channel: data.channel, text: "Of a total #{nodecount} nodes")
          else
            client.say(channel: data.channel, text: "Can't say I know how to do that")
          end
        else
          client.say(channel: data.channel, text: "I don't have credentials to access the orchestration service")
        end
      end
    end
  end
end
