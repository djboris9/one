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

require 'yaml'
require 'json'

class SunstonePlugins
    attr_reader :plugins_conf

    def initialize
        load_conf
        check_plugins
    end

    def load_conf
        @plugins_conf = YAML.load_file(PLUGIN_CONFIGURATION_FILE)
    end

    def check_plugins
        base_path = SUNSTONE_ROOT_DIR+'/public/js/'

        @installed_plugins = Array.new

        # read user plugins
        Dir[base_path+'user-plugins/*.js'].each do |p_path|
            m = p_path.match(/^#{base_path}(.*)$/)
            if m && m[1]
                @installed_plugins << m[1]
            end
        end

        # read base plugins
        Dir[base_path+'plugins/*.js'].each do |p_path|
            m = p_path.match(/^#{base_path}(.*)$/)
            if m && m[1]
                @installed_plugins << m[1]
            end
        end
    end

    def plugins
        @plugins_conf.collect{|p| p.keys[0]}
    end

    def installed?(plugin)
        @installed_plugins.include? plugin
    end

    def authorized_plugins(user, group)
        auth_plugins = {"user-plugins"=>Array.new, "plugins"=>Array.new}

        @plugins_conf.each do |plugin_conf|
            plugin = plugin_conf.keys.first
            perms  = plugin_conf[plugin]

            if installed?(plugin)
                p_path, p_name = plugin.split('/')

                if perms[:user] and perms[:user].has_key? user
                    if perms[:user][user]
                        auth_plugins[p_path] << p_name
                    else
                        next
                    end
                elsif perms[:group] and perms[:group].has_key? group
                    if perms[:group][group]
                        auth_plugins[p_path] << p_name
                    else
                        next
                    end
                elsif perms[:ALL]
                    auth_plugins[p_path] << p_name
                end
            end
        end
        auth_plugins
    end

    def to_json
        @plugins_conf.to_json
    end
end
