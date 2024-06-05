# Fluence module

Here we have definition what to install into ami related to Fluence needs.
After adding new script remember to add it to os distro template definition so it would be called. Also depending on needs it could be parametrized.

Example addition to template.json
```
    ...
    {
      "type": "shell",
      "remote_folder": "{{ user `remote_folder`}}",
      "script": "{{template_dir}}/../fluence/provisioners/load_kernel_modules.sh",
      "environment_vars": [
        "ENABLE_FLUENCE_KERNEL_MODULES={{user `enable_fluence_kernel_modules`}}"
      ]
    },
    ...
```