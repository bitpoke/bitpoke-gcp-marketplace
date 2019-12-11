# Manifests documentation

Template files that will be applied by the deployer:
 * `application.yaml.template`: it creates the Dashboard application resource
 * `manifest_dashboard.yaml.template`: it installs the dashboard apiserver and controller
 * `manifest_globals_job.yaml.template`: it creates the Dashboard related CRDs, ClusterRole, Certificates and Issuers; also, it creates the `presslabs-system` namespace
 * `manifest_stack_installer_job.yaml.template`: it creates a job which will install [Stack](https://github.com/presslabs/stack/) via helm
