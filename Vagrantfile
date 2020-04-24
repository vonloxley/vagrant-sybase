Vagrant.configure(2) do |config|
  config.vm.box = "bento/centos-6.10"
  config.vm.hostname = "dockerhost"
  config.ssh.insert_key = true
  config.ssh.forward_agent = true
  config.vm.network :forwarded_port, guest: 5000, host: 5001
  
  # Disable gw - turn off inet
  #config.vm.provision "shell", run: "always", inline: "ip route flush 0/0"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
  end

  config.vm.provision :shell, :path => "common.sh"
end

