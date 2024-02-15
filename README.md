# Kong Customer Success Tools

Welcome to the tools section of the Kong Customer Success team. As of this moment, the toolbox contains a single, albeit important, tool: **Kong Interactive Consumption Kollector - KICK**.

The purpose of **KICK** is to provide a simple mechanism for counting the number of services (total and discrete) across one or more Kong Enterprise environments, and gather an understanding of how many duplicate services exist across one's Kong estate.

The general definition of a service is "a discrete unit of programmatic functionality that is exposed for remote consumption and managed through the Software." As such, **KICK** defines a discrete service by leveraging different components that make up a gateway service in Kong Gateway; namely:

     protocol://host:port/path

So, for example, a discrete service could be:

    https://catfacts.ninja/fact

As you may know, a service in Kong Gateway can have many routes associated with it; from the **KICK** lense, 1 or 1000 routes are irrelevant as long as they are attached to the same service. From the perspective of **KICK** that will count as 1 (one) discrete service.

## Requirements

As with any software, there are some prerequisists that must be met. At the very minimum you need to know the Admin API URL and the KONG_ADMIN_TOKEN value used to communicate with the Admin API, and jq.

**KICK** runs in a bash shell, so either a Mac or a Linux machine are necessary to execute the script.

### Environments File

Since the objective of **KICK** is to count discrete services across a user's Kong estate, it is only logical to expect one or more Kong clusters. For this, a JSON file containing details of said environments must be passed in as an input parameter to **KICK**. An example can be found in [test/envs.json](test/envs.json); the general form is as follows:

    [
      {
        "environment": "dev",
        "admin_host": "https://dev_admin_api_host:8001",
        "admin_token": "foobar",
        "license_report: 1
      },
      {
        "environment": "prod",
        "admin_host": "https://prod_admin_api_host:8001",
        "admin_token": "foobar",
        "license_report: 1
      }
    }

In the example above, there are 2 Kong environments--dev and prod. As mentioned earlier, in order for **KICK** to connect to the Admin API in each Kong environment the KONG_ADMIN_TOKEN value must be passed in the request's header.

### JQ

[jq](https://jqlang.github.io/jq/) is the tool that allows **KICK** to do its magic. If you don't have jq installed, please do so or else you will render **KICK** useless.

## Running KICK

Download [kick.sh](tools/kick.sh) to your Mac or Linux machine, and make sure to change the permissions on the file:

    $ chmod +x kick.sh

You can get creative and add kick.sh to your path if you'd like to make execution more flexible. Ok, now take it for a drive:

    $ ./kick.sh -i envs.json

That it is. Assuming you used the example above, the output you will see on your terminal screen should be something like this:

    KONG CLUSTER: prod
    ADMIN HOST  : https://prod_admin_api_host:8001
    ┌─────────────┬──────────────┬──────────────────┐
    │Workspace    │Gateway Svcs  │Discrete Svcs     │
    ├─────────────┼──────────────┼──────────────────┤
    │Engineering  │1             │1                 │
    │WS1          │0             │0                 │
    │WS2          │0             │0                 │
    │WS3          │0             │0                 │
    │default      │19            │17                │
    │             │              │                  │
    │Total        │20            │18 (x-workspace)  │
    └─────────────┴──────────────┴──────────────────┘

    KONG CLUSTER: dev
    ADMIN HOST  : https://dev_admin_api_host:8001
    ┌─────────────┬──────────────┬──────────────────┐
    │Workspace    │Gateway Svcs  │Discrete Svcs     │
    ├─────────────┼──────────────┼──────────────────┤
    │Engineering  │1             │1                 │
    │WS1          │0             │0                 │
    │WS2          │0             │0                 │
    │WS3          │0             │0                 │
    │default      │19            │17                │
    │             │              │                  │
    │Total        │20            │18 (x-workspace)  │
    └─────────────┴──────────────┴──────────────────┘

    ┌───────────────┬──────────────────┬──────────────┬───────────────┐
    │Kong Clusters  │Total Workspaces  │Gateway Svcs  │Discrete Svsc  │
    ├───────────────┼──────────────────┼──────────────┼───────────────┤
    │2              │10                │40            │18             │
    └───────────────┴──────────────────┴──────────────┴───────────────┘

## Question or Feedback

**KICK** is in its infancy. If you have suggestions for improvements or run into any trouble executing **KICK**, please contact your Kong account team (Account Executive or Customer Success Manager) for assistance.

## Disclaimer

**KICK** it **NOT** a Kong product, nor is it supported by Kong. This script is only made available to help understand the sprawl (if any) of duplicate services in a user's Kong environment. **KICK** is read-only as it relates to Kong Gateway; the source code is provided in efforts of full transparency, and the ability to modify if needed.
      
