#!/usr/bin/env python3
import xml.etree.ElementTree as ET
from operator import itemgetter
import subprocess as sp
import platform
import re
import sys
import os


def get_os_release():
    # deprecated in 3.7 -> distro.linux_distribution()
    return float(platform.linux_distribution()[1])


def get_fqdn():
    fqdn = sp.getoutput('hostname --fqdn')
    return fqdn.lower()


def get_mq_cluster(environment):
    nodes = []
    pattern = '(?<=CERN\.)(.*?)(?=\.)'
    mq_cluster_info = sp.getoutput('dspmq')
    for line in iter(mq_cluster_info.splitlines()):
        if environment.lower() in line.lower():
            match = re.search(pattern, line)
            nodes.append(match.group())
    mq_cluster_nodes = ",".join(sorted(nodes)).lower()
    return mq_cluster_nodes


def get_process_id(process_name):
    child = sp.Popen(['pgrep', '-f', process_name], stdout=sp.PIPE, shell=False)
    response = child.communicate()[0]
    pid_list = [int(pid) for pid in response.split()]
    if len(pid_list) > 0:
        return True
    else:
        return False


def is_cluster(cluster_config_file, environment):
    if os.path.isfile(cluster_config_file):
        with open(cluster_config_file) as f:
            # ensure the environment name exists in the cluster config to determine if the cluster is associated to the domain
            if environment.lower() in f.read().lower():
                return True
            else:
                return False
    else:
        return False


def parse_cluster_config(cluster_config_file):
    cluster_nodes = []
    tree = ET.parse(cluster_config_file)
    root = tree.getroot()
    # store cluster name
    for value in root.findall('.//nvpair[@name="cluster-name"]'):
        cluster_name = value.attrib['value']
    for node in root.iter('node'):
        cluster_nodes.append(node.get('uname'))
    cluster_node_count = len(cluster_nodes)
    # generate a string of numerically ordered comma separated nodes that are clustered with the local node inclusive
    cluster_nodes = ",".join(sorted(cluster_nodes))
    # return all parsed values as a dictionary
    return {'cluster_name': cluster_name, 'cluster_nodes': cluster_nodes, 'cluster_node_count': cluster_node_count}


def get_atg_version(atg_file):
    pattern = "(?<=Script version)*[0-9]+"
    if os.path.isfile(atg_file):
        with open(atg_file) as f:
            f = f.read()
            match = re.search(pattern, f)
            if match:
                return int(match.group())
            else:
                return None
    else:
        return None


def get_lreg_property(environment, property):
    lreg_key = "cernerha"
    lreg_command = "lreg -getp \\\\{lreg_key}\\\\{environment}\\\\ {property} 2>/dev/null".format(lreg_key=lreg_key,
                                                                                                  environment=environment,
                                                                                                  property=property)
    property_val = sp.getoutput(lreg_command)
    return property_val


def main():
    if get_os_release() < 7:
        sys.exit()

    # set our configuration files
    cluster_config_file = '/var/lib/pacemaker/cib/cib.xml'
    atg_file = '/usr/local/cluster/cerner.functions'

    # abort if there environment is not set or if the environment is not clustered
    if not os.getenv('environment'):
        sys.exit()
    else:
        environment = os.getenv('environment')

    #initialize variables
    fqdn = None
    atg_version = None
    cluster_name = None
    cluster_nodes = None
    cluster_node_count = None
    core_fsi_node = None
    ha_interface_home_node = None
    ha_single_inst_list = None
    mq_cluster = None

    if not is_cluster(cluster_config_file, environment):
        sys.exit()

    fqdn = get_fqdn()

    if is_cluster(cluster_config_file, environment):
        cluster_config = parse_cluster_config(cluster_config_file)
        cluster_name, cluster_nodes, cluster_node_count = itemgetter('cluster_name', 'cluster_nodes', 'cluster_node_count')(cluster_config)

    atg_version = get_atg_version(atg_file)

    if get_process_id('reg_server'):
        core_fsi_node = get_lreg_property(environment, 'CoreFSINode')
        ha_interface_home_node = get_lreg_property(environment, 'HAInterfaceHomeNode')
        ha_single_inst_list = get_lreg_property(environment, 'HASingleInstList')

    mq_cluster = get_mq_cluster(environment)

    print(f'<fqdn>{fqdn or ""}</fqdn>\
<atg_version>{atg_version or ""}</atg_version>\
<cluster_name>{cluster_name or ""}</cluster_name>\
<cluster_nodes>{cluster_nodes or ""}</cluster_nodes>\
<cluster_node_count>{cluster_node_count or ""}</cluster_node_count>\
<core_fsi_node>{core_fsi_node or ""}</core_fsi_node>\
<ha_interface_home_node>{ha_interface_home_node or ""}</ha_interface_home_node>\
<ha_single_inst_list>{ha_single_inst_list or ""}</ha_single_inst_list>\
<mq_cluster>{mq_cluster or ""}</mq_cluster>')


if __name__ == "__main__":
    main()
