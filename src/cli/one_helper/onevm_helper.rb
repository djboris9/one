# -------------------------------------------------------------------------- #
# Copyright 2002-2013, OpenNebula Project (OpenNebula.org), C12G Labs        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'one_helper'

class OneVMHelper < OpenNebulaHelper::OneHelper
    MULTIPLE={
        :name  => "multiple",
        :short => "-m x",
        :large => "--multiple x",
        :format => Integer,
        :description => "Instance multiple VMs"
    }

    IMAGE = {
        :name   => "image",
        :short  => "-i id|name",
        :large  => "--image id|name" ,
        :description => "Selects the image",
        :format => String,
        :proc   => lambda { |o, options|
            OpenNebulaHelper.rname_to_id(o, "IMAGE")
        }
    }

    FILE = {
        :name   => "file",
        :short  => "-f file",
        :large  => "--file file" ,
        :description => "Selects the template file",
        :format => String,
        :proc   => lambda { |o, options|
            if File.file?(o)
                options[:file] = o
            else
                exit -1
            end
        }
    }

    HOLD = {
        :name  => "hold",
        :large => "--hold",
        :description => "Creates the new VM on hold state instead of pending"
    }

    def self.rname
        "VM"
    end

    def self.conf_file
        "onevm.yaml"
    end

    def self.state_to_str(id, lcm_id)
        id = id.to_i
        state_str = VirtualMachine::VM_STATE[id]
        short_state_str = VirtualMachine::SHORT_VM_STATES[state_str]

        if short_state_str=="actv"
            lcm_id = lcm_id.to_i
            lcm_state_str = VirtualMachine::LCM_STATE[lcm_id]
            return VirtualMachine::SHORT_LCM_STATES[lcm_state_str]
        end

        return short_state_str
    end

    def format_pool(options)
        config_file = self.class.table_conf

        table = CLIHelper::ShowTable.new(config_file, self) do
            column :ID, "ONE identifier for Virtual Machine", :size=>6 do |d|
                d["ID"]
            end

            column :NAME, "Name of the Virtual Machine", :left,
                    :size=>15 do |d|
                if d["RESCHED"] == "1"
                    "*#{d["NAME"]}"
                else
                    d["NAME"]
                end
            end

            column :USER, "Username of the Virtual Machine owner", :left,
                    :size=>8 do |d|
                helper.user_name(d, options)
            end

            column :GROUP, "Group of the Virtual Machine", :left,
                    :size=>8 do |d|
                helper.group_name(d, options)
            end

            column :STAT, "Actual status", :size=>4 do |d,e|
                OneVMHelper.state_to_str(d["STATE"], d["LCM_STATE"])
            end

            column :UCPU, "CPU percentage used by the VM", :size=>4 do |d|
                d["CPU"]
            end

            column :UMEM, "Memory used by the VM", :size=>7 do |d|
                OpenNebulaHelper.unit_to_str(d["MEMORY"].to_i, options)
            end

            column :HOST, "Host where the VM is running", :left, :size=>10 do |d|
                if d['HISTORY_RECORDS'] && d['HISTORY_RECORDS']['HISTORY']
                    state_str = VirtualMachine::VM_STATE[d['STATE'].to_i]
                    if %w{ACTIVE SUSPENDED}.include? state_str
                        d['HISTORY_RECORDS']['HISTORY']['HOSTNAME']
                    end
                end
            end

            column :TIME, "Time since the VM was submitted", :size=>10 do |d|
                stime = d["STIME"].to_i
                etime = d["ETIME"]=="0" ? Time.now.to_i : d["ETIME"].to_i
                dtime = etime-stime
                OpenNebulaHelper.period_to_str(dtime, false)
            end

            default :ID, :USER, :GROUP, :NAME, :STAT, :UCPU, :UMEM, :HOST,
                :TIME
        end

        table
    end

    private

    def factory(id=nil)
        if id
            OpenNebula::VirtualMachine.new_with_id(id, @client)
        else
            xml=OpenNebula::VirtualMachine.build_xml
            OpenNebula::VirtualMachine.new(xml, @client)
        end
    end

    def factory_pool(user_flag=-2)
        OpenNebula::VirtualMachinePool.new(@client, user_flag)
    end

    def format_resource(vm)
        str_h1="%-80s"
        str="%-20s: %-20s"

        CLIHelper.print_header(
            str_h1 % "VIRTUAL MACHINE #{vm['ID']} INFORMATION")
        puts str % ["ID", vm.id.to_s]
        puts str % ["NAME", vm.name]
        puts str % ["USER", vm['UNAME']]
        puts str % ["GROUP", vm['GNAME']]
        puts str % ["STATE", vm.state_str]
        puts str % ["LCM_STATE", vm.lcm_state_str]
        puts str % ["RESCHED", OpenNebulaHelper.boolean_to_str(vm['RESCHED'])]
        puts str % ["HOST",
            vm['/VM/HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']] if
                %w{ACTIVE SUSPENDED}.include? vm.state_str
        puts str % ["START TIME",
            OpenNebulaHelper.time_to_str(vm['/VM/STIME'])]
        puts str % ["END TIME",
            OpenNebulaHelper.time_to_str(vm['/VM/ETIME'])]
        value=vm['DEPLOY_ID']
        puts str % ["DEPLOY ID", value=="" ? "-" : value]

        puts

        CLIHelper.print_header(str_h1 % "VIRTUAL MACHINE MONITORING",false)
        poll_attrs = {
            "USED MEMORY" => "MEMORY",
            "USED CPU" => "CPU",
            "NET_TX" => "NET_TX",
            "NET_RX" => "NET_RX"
        }

        poll_attrs.each { |k,v|
            if k == "USED CPU"
                puts str % [k,vm[v]]
            elsif k == "USED MEMORY"
                puts str % [k, OpenNebulaHelper.unit_to_str(vm[v].to_i, {})]
            else
                puts str % [k, OpenNebulaHelper.unit_to_str(vm[v].to_i/1024, {})]
            end
        }
        puts

        CLIHelper.print_header(str_h1 % "PERMISSIONS",false)

        ["OWNER", "GROUP", "OTHER"].each { |e|
            mask = "---"
            mask[0] = "u" if vm["PERMISSIONS/#{e}_U"] == "1"
            mask[1] = "m" if vm["PERMISSIONS/#{e}_M"] == "1"
            mask[2] = "a" if vm["PERMISSIONS/#{e}_A"] == "1"

            puts str % [e,  mask]
        }
        puts

        CLIHelper.print_header(str_h1 % "VIRTUAL MACHINE TEMPLATE",false)
        puts vm.template_str

        if vm.has_elements?("/VM/USER_TEMPLATE")
            puts

            CLIHelper.print_header(str_h1 % "USER TEMPLATE",false)
            puts vm.template_like_str('USER_TEMPLATE')
        end

        if vm.has_elements?("/VM/HISTORY_RECORDS")
            puts

            CLIHelper.print_header(str_h1 % "VIRTUAL MACHINE HISTORY",false)
            format_history(vm)
        end
    end

    def format_history(vm)
        table=CLIHelper::ShowTable.new(nil, self) do
            column :SEQ, "Sequence number", :size=>4 do |d|
                d["SEQ"]
            end

            column :HOST, "Host name of the VM container", :left, :size=>15 do |d|
                d["HOSTNAME"]
            end

            column :REASON, "VM state change reason", :left, :size=>6 do |d|
                VirtualMachine.get_reason d["REASON"]
            end

            column :START, "Time when the state changed", :size=>15 do |d|
                OpenNebulaHelper.time_to_str(d['STIME'])
            end

            column :TIME, "Total time in this state", :size=>15 do |d|
                stime = d["STIME"].to_i
                etime = d["ETIME"]=="0" ? Time.now.to_i : d["ETIME"].to_i
                dtime = etime-stime
                OpenNebulaHelper.period_to_str(dtime)
            end

            column :PROLOG_TIME, "Prolog time for this state", :size=>15 do |d|
                stime = d["PSTIME"].to_i
                if d["PSTIME"]=="0"
                    etime=0
                else
                    etime = d["PETIME"]=="0" ? Time.now.to_i: d["PETIME"].to_i
                end
                dtime = etime-stime
                OpenNebulaHelper.period_to_str(dtime)
            end

            default :SEQ, :HOST, :REASON, :START, :TIME, :PROLOG_TIME
        end

        vm_hash=vm.to_hash

        history=[vm_hash['VM']['HISTORY_RECORDS']['HISTORY']].flatten

        table.show(history)
    end
end
