module Merb
  module ClientsHelper
    # Takes clients and returns them as a grouped hash

    def grouped_clients(clients)
      clients.group_by{|c| c.client_group ? c.client_group.name : "No Group"}
      current_clients = clients.values.flatten
      clients["Ex Clients"] = []
      @center.loans(@date).each do |l|
        clients["Ex Clients"] << l.client unless current_clients.include?(l.client)
      end
      clients.each{|k, v|
        clients[k]=v.sort_by{|c| c.name} if v
      }.sort.collect{|k, v| v}.flatten
      clients
    end
  end
end
