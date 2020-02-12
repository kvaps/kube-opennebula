FROM docker.io/kvaps/opennebula-sunstone:v5.10.1

USER root
RUN sed -i 's/  - \(support\|marketplaces-tab\)/  #\1/' \
      /etc/one/sunstone-views/*/*.yaml \
 && sed -i 's/\(vcenter_vm_folder\|import_dialog\): true/\1: false/g' \
      /etc/one/sunstone-views/mixed/*.yaml

USER oneadmin
