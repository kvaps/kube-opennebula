FROM docker.io/kvaps/opennebula-sunstone:v5.10.1

USER root
RUN sed -i 's/  - \(support\|marketplaces-tab\)/  #\1/' \
      /etc/one/sunstone-views/*/*.yaml \
 && sed -i 's/\(vcenter_vm_folder\|import_dialog\): true/\1: false/g' \
      /etc/one/sunstone-views/mixed/*.yaml \
 && sed /etc/one/sunstone-views/mixed/user.yaml \
    -e '/^    show_attributes_info/a\    show_as_uid_instantiate: false\n\    show_as_gid_instantiate: false' \
    -e 's/\(show_ds_instantiate\|show_host_instantiate\|VM.migrate_live\): false/\1: true/' \
    -e 's/\(.chmod\|.chown\|.chgrp\): true/\1: false/' \
    -e 's/MarketPlaceApp.\(create_dialog\|download_local\|rename\|enable\|disable\|delete\|edit_labels\|menu_labels\): true/\1: false/' \
    > /etc/one/sunstone-views/mixed/advanced.yaml

USER oneadmin
