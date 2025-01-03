# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: proto/health_service.proto

require 'google/protobuf'

require 'google/api/annotations_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("proto/health_service.proto", :syntax => :proto3) do
    add_message "gitlab.cells.topology_service.ReadinessProbeRequest" do
    end
    add_message "gitlab.cells.topology_service.ReadinessProbeResponse" do
    end
    add_message "gitlab.cells.topology_service.LivenessProbeRequest" do
    end
    add_message "gitlab.cells.topology_service.LivenessProbeResponse" do
    end
  end
end

module Gitlab
  module Cells
    module TopologyService
      ReadinessProbeRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("gitlab.cells.topology_service.ReadinessProbeRequest").msgclass
      ReadinessProbeResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("gitlab.cells.topology_service.ReadinessProbeResponse").msgclass
      LivenessProbeRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("gitlab.cells.topology_service.LivenessProbeRequest").msgclass
      LivenessProbeResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("gitlab.cells.topology_service.LivenessProbeResponse").msgclass
    end
  end
end
