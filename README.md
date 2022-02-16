

## Overview

This documents how to perform Initial 5EC/NC vSRX Configuration in the CNCFW Role.

## Version 1.0

This version of the playbooks is intended to work with Ansible 2.4.x and Juniper.JUNOS stdlib 2.0.2.

### PreRequisites
* Juniper.junos Ansible Modules version 2.0.2
* Ansible 2.4.x
* MechUser Accounts (with Admin access to MNS) @ https://www.e-access.att.com/src/MiscIDSponshipBulkServlet
  - Ansible Juniper_OS Modules: Local vSRX account or GTAC account with SSH Keys configured.  This will be used to perform operations on the vSRX itself during the configuration

* Create SSH Keys for MechUser account on Linux host
  - Naming of Public and Private keys are important due to a bug in the Ansible Juniper.junos module ( https://github.com/Juniper/ansible-junos-stdlib/issues/85 ). The bug the prevents usage of keys named anything other than:
    ```ssh
    Private: id_rsa
    Public: id_rsa.pub
    ```
  - Please note: If you use anything other than the stock/default id_rsa* keys in your ~/<home>/.ssh directory, you will need to specify the location and files of the SSH keys in the ansible.cfg file or via command line during ansible-playbook execution.

* (This will be done via config-drive/cloud-init) Configure vSRX with MechUser account with SSH-KEY and NetConf via SSH (Alternatively, use User/Pass instead of SSH-KEY).
  - vSRX user should have full access / admin rights to perform upgrades.
  - E.g.
    ```junos
    system {
          login {
              user {{VSRX_MECHUSER}} {
              full-name "Ansible and Automation MechUser";
              uid 9997;
              class super-user;
              authentication {
                  encrypted-password "{{VSRX_SUPERUSER_PASSWORD}}"; ## SECRET-DATA
                  ssh-rsa "{{VSRX_SUPERUSER_SSHKEY}} myuser@WACDTL01myuser"; ## SECRET-DATA
                  }
              }
          }
          services {
              netconf {
                  ssh;
                  }
              }
          }
    ```

### Dependencies
This modules requires the following to be installed on the Ansible control machine:
- Python 2.7x
- Ansible 2.4.x
- Junos py-junos-eznc 2.1.7 or later
- jxmlease 1.0.1 or later

### Roadmap
- Integrate Policy Configuration with JUNOS Space
- Run playbooks "As A Service" in a CI/CD integrated environment with App-C API triggers


### Firewall Config Files
Configuration Jinja2 Templates are stored in the ```templates``` directory of each role for ```03-cfgbaseprimary``` or ```04-cfgpolicyprimary```. For now, we will use Jinja2 Templates for policy for "Day Zero" but will be moving to JUNOS Space integration for "Day One".


### Usage

##### ~/hosts Configuration
We are using ```roles``` and sequencing to help with stepping through the Initial Configuration of the 5EC
```
[node0]
zsde1frwl02cnc-node0 ansible_host=172.17.32.132

[node1]
zsde1frwl02cnc-node1 ansible_host=172.17.32.133
```
##### Important Variables
In each of the roles, take a look at the variables (```~/roles/[role]/vars/main.yml```) needed for the playbooks to consume.

##### Verify Log Directories are Created

```
$ mkdir -p log/config
$ mkdir -p log/output
$ mkdir -p log/debug
```

##### Execute Playbooks
```
$ ansible-playbook site.yml -vvvv

```
## Playbook Steps:
* 01-cfgbase
  - vSRX Base Configuration
* 02-cfgpolicy
  - vSRX Policy Configuration
* 99-cfgzero
  - vSRX Zero Config (Rollbac to New Build)

## Ansible Folder Structure

```FolderStructure
# ~/ == playbook directory

~/
    /files/
    /group_vars/
        /all/
            vars.yml
            vault.yml.clear
            vault.yml
        00-common.yml
        01-cfgbase_node0.yml
        02-cfgbase_node1.yml
        03-cfgpolicy.yml
        99-cfgzero.yml
    /log/
        /config/
        /debug/
        /output/
    /roles/
        /00-common/
            /tasks/
                galaxy-pause_30.yml
                galaxy-pause_60.yml
                galaxy-pause_300.yml
                galaxy-wait_for_netconf_30.yml
                galaxy-wait_for_netconf_60.yml
                galaxy-wait_for_netconf_300.yml
                galaxy-wait_for_netconf_600.yml
                juniper_junos_config_retrieve.yml
                juniper_junos_facts.yml
        /01-cfgbase_node0/
            /tasks/
                juniper_junos_config_overwrite.yml
                main.yml
            /templates/
                base_cfg.j2
            /vars/
                main.yml
        /02-cfgbase_node1/
            /tasks/
                juniper_junos_config_overwrite.yml
                main.yml
            /templates/
                base_cfg.j2
            /vars/
                main.yml
        /03-cfgpolicy/
            /tasks/
                juniper_junos_config_merge.yml
                main.yml
            /templates/
                policy_cfg.j2
            /vars/
                main.yml
        /04-space_add_pm_context/
        /05-space_assign_policy/
        /06-space_publish_policy/
        /07-space_update_policy
/
        /99-cfgzero/
            /tasks/
                juniper_junos_config_merge.yml
                main.yml
            /templates/
                zero_cfg.j2
            /vars/
                main.yml
    .dockerignore
    .gitignore
    ansible.cfg
    Dockerfile
    Dockerfile.initial
    hosts
    Jenkinsfile.internal
    Jenkinsfile.external
    LICENSE
    README.md
    site.yml
    zero.yml

```
## Initial AaaS Worker Build

* Build Initial Container: In the root of your afw-worker repo, execute:

```
$ docker build -t afw-worker-cloudvsrxcnc:initial -f Dockerfile.initial .

$ docker image tag afw-worker-cloudvsrxcnc:initial afw-worker-cloudvsrxcnc:latest

$ docker tag afw-worker-cloudvsrxcnc:initial 127.0.0.1:<registry port>/afw-worker-cloudvsrxcnc:initial

$ docker tag afw-worker-cloudvsrxcnc:latest 127.0.0.1:<registry port>/afw-worker-cloudvsrxcnc:latest
```

* Push Container to Registry

```
$ docker push 127.0.0.1:<registry port>/afw-worker-cloudvsrxcnc:initial

$ docker push 127.0.0.1:<registry port>/afw-worker-cloudvsrxcnc:latest

$ curl http://127.0.0.1:{{SVC_PORT}}/v2/_catalog
{"repositories":["afw-worker-cloudvsrxcnc"]}

$ curl http://127.0.0.1:{{SVC_PORT}}/v2/afw-worker-cloudvsrxcnc/tags/list 
{"name":"afw-worker-cloudvsrxcnc","tags":["initial","latest"]}
```    

* Create Kubernetes Deployment

```
$ helm install --name wkcloudvsrxcnc ~/helm_chart -f ~/helm_chart/values.yaml
NAME:   wkcloudvsrxcnc
LAST DEPLOYED: Fri Sep 14 20:24:16 2018
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Service
NAME                                    TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)  AGE
wkcloudvsrxcnc-worker-cloudvsrxcnc  ClusterIP  10.96.74.89  <none>       22/TCP   0s

==> v1beta2/Deployment
NAME                                    DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
wkcloudvsrxcnc-worker-cloudvsrxcnc  1        1        1           0          0s

==> v1/Pod(related)
NAME                                                     READY  STATUS             RESTARTS  AGE
wkcloudvsrxcnc-worker-cloudvsrxcnc-5845fd7c56-dffrq  0/1    ContainerCreating  0         0s


NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app=worker-cloudvsrxcnc,release=wkcloudvsrxcnc" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl port-forward $POD_NAME 8080:80
```

* Access Container
```
$ kubectl exec -it $(kubectl get pods | grep -i worker-cloudvsrxcnc | awk '{print $1}') ash
```

## Ongoing/BAU AaaS Worker Build
From this point forward, AaaS Worker builds will be facilitated via CICD GIT => JENKINS => REGISTRY => DEPLOY Process

## Reference
- https://github.com/Juniper/ansible-junos-stdlib
- https://junos-ansible-modules.readthedocs.io/en/2.0.2/
