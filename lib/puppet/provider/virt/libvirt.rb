Puppet::Type.type(:virt).provide(:libvirt) do
	@doc = ""

	commands :virtinstall => "/usr/bin/virt-install"
	commands :grep => "/bin/grep"

	# The provider is choosed by virt_type, not by operating system
	confine :feature => :libvirt

	# 
	def dom

		Libvirt::open("qemu:///session").lookup_domain_by_name(resource[:name])

	end

	#
	def install(bootoninstall = true)

		virt_parameter = case resource[:virt_type]
					when :xen_fullyvirt then "--hvm" #must validate kernel support
					when :xen_paravirt then "--paravirt" #Must validate kernel support
					when :kvm then "--accelerate" #Must validate hardware support
					else "Invalid value" # FIXME Raise something here?
		end

		debug "Boot on install: %s" % bootoninstall
		debug "Virtualization type: %s" % [resource[:virt_type]]

		arguments = ["--name", resource[:name], "--ram", resource[:memory], "--vcpus" , resource[:cpus], "--noautoconsole", "--force", virt_parameter, "--file", resource[:virt_path]]

		if !bootoninstall
			arguments << "--noreboot"
		end

		if File.exists?(resource[:virt_path])
			debug "File already exists. Importing domain"
			arguments << "--import"
		else
			debug "Creating new domain."

			# Future work
			# --pxe
			# ["--location", resource[:boot_location]]
			# ["--size", resource[:disk_size]]
		end

#TODO		network = ["--network", resource[:interfaces]]

		virtinstall arguments 

	end

	# Changing ensure to absent
	def destroy #Changing ensure to absent

		debug "Trying to destroy domain %s" % [resource[:name]]

		begin
			dom.destroy
		rescue Libvirt::Error => e
			debug "Domain %s already Stopped" % [resource[:name]]
		end
		dom.undefine

	end


	# Creates config file if absent, and makes sure the domain is not running.
	def stop

		debug "Stopping domain %s" % [resource[:name]]

		if !exists?
			install(false)
		elsif status == "running"
#			dom.shutdown #FIXME Qemu does't support shutdown gracefully 
			dom.destroy
		end

	end


	# Creates config file if absent, and makes sure the domain is running.
	def start

		debug "Starting domain %s" % [resource[:name]]

		if exists? && status != "running"
			dom.create # Start the domain
		elsif status == "absent"
			install
		end

	end


	# Creates config file if absent, but doesn't touch the domain's state.
	# FIXME I dont like this method name
	def setinstalled

		debug "Checking if the domain %s already exists." % [resource[:name]]

		if !exists?
			install(false)
		end

	end

	# Auxiliary method to make sure the domain exists before change it's properties.
	#
	def setpresent
		case resource[:ensure]
			when :absent then return #do nothing
			when :running then install(true)
			else install(false)
		end
	end

	# Check if the domain exists.
	def exists?

		begin
			dom
			debug "Domain %s exists? true" % [resource[:name]]
			true
		rescue Libvirt::RetrieveError => e
			debug "Domain %s exists? false" % [resource[:name]]
			false # The vm with that name doesnt exist
		end

	end


	# running | stopped | absent,				
	def status

		if exists? 
			# 1 = running, 3 = paused|suspend|freeze, 5 = stopped 
			if resource[:ensure].to_s == "installed"
				return "installed"
			elsif dom.info.state != 5
				debug "Domain %s status: running" % [resource[:name]]
				return "running"
			else
				debug "Domain %s status: stopped" % [resource[:name]]
				return "stopped"
			end
		else
			debug "Domain %s status: absent" % [resource[:name]]
			return "absent"
		end

	end

	# Is the domain autostarting?
	def autoboot

		if !exists?
			setpresent
		end
	
		return dom.autostart.to_s

	end


	# Set true or false to autoboot property
	def autoboot=(value)

		debug "Trying to set autoboot %s at domain %s." % [resource[:autoboot], resource[:name]]
		begin
			if value.to_s == "false"
				dom.autostart=(false)
			else
				dom.autostart=(true)
			end
		rescue Libvirt::RetrieveError => e
			debug "Domain %s not defined" % [resource[:name]]
		end

	end

	# Not implemented by libvirt yet
	def on_poweroff

		path = "/etc/libvirt/qemu/" #Debian/ubuntu path for qemu's xml files
		extension = ".xml"
		xml = path + resource[:name] + extension

		if File.exists?(xml)
			arguments =  ["poweroff", file]
			line = ""
			debug "Line: %s" % [line]
			line = grep arguments
			return line.split('>')[1].split('<')[0]	
		else
			return :absent
		end

	end

	#
	def on_poweroff=(value)
		# Not implemented by libvirt yet
	end

	#
	def on_reboot
		# Not implemented by libvirt yet
	end

	#
	def on_reboot=(value)
		# Not implemented by libvirt yet
	end

	#
	def on_crash
		# Not implemented by libvirt yet
	end

	#
	def on_crash=(value)
		# Not implemented by libvirt yet
	end

end
