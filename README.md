# Kong Customer Success Tools

Welcome to the tools section of the Kong Customer Success team. As of this moment, the toolbox contains a single, albeit important, tool: **Kong License Consumption Report - KLCR**.

The purpose of KLCR (pronounced "clicker", and newly renamed from KICK to avoid confusion with Kong's KIC--Kubernetes Ingress Controller) is to provide a simple mechanism for counting the number of services (total and discrete) across one or more Kong Enterprise environments, and gather an understanding of how many duplicate services exist across one's Kong estate.

The general definition of a service is "a discrete unit of programmatic functionality that is exposed for remote consumption and managed through the Software." As such, KLCR defines a discrete service by leveraging different components that make up a service in Kong Gateway; namely:

     protocol://host:port/path

So, for example, a discrete service could be:

    https://catfact.ninja/fact

As you may know, a service in Kong Gateway can have many routes associated with it; from the KLCR lens, 1 or 1000 routes are irrelevant as long as they are attached to the same service. From the perspective of KLCR that will count as 1 (one) discrete service.

KLCR also gathers the license report for each Kong environment provided, and stores the output in a JSON file. All files generated are placed in the provided output directory (see below).

## Version

2.2.1 is the latest version of the Kong License Consumption Report.

## Requirements

As with any software, there are some prerequisists that must be met. At the very minimum you need to know the credentials used to communicate with the Admin API (or Konnect API), and jq.

KLCR runs in a bash shell, so either a Mac or a Linux machine are necessary to execute the script.

### Environments File

Since the objective of KLCR is to count discrete services across a user's Kong estate, it is only logical to expect one or more Kong clusters. For this, a JSON file containing details of said environments must be passed in as an input parameter to KLCR. An example can be found in [input/envs.json](input/envs.json); the general form is as follows:

    {
        "environments":
        [
            {
                "environment": "local",
                "admin_api": "https://prod_admin_api:8001",
                "admin_token": "kong_admin",
                "deployment": "enterprise"
            },
            {
                "environment": "dr",
                "admin_api": "https://dr_admin_api:8001",
                "admin_token": "kong_admin",
                "deployment": "enterprise"
            },            
            {
                "environment": "aws1",
                "admin_api" : "https://us.api.konghq.com/v2",
                "admin_token": "kpat_konnectaccesstoken",
                "deployment": "konnect",
                "control_plane_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   // optional -- See Konnect section below
            }    
        ],
        "discrete": {
            "master": "prod",
            "minions": "dev|stage|qa"
        }
    }

In the example above, there are 3 Kong environments: *prod* and *dr* are 2 Kong Enterprise environments, and *aws1* is a Konnect environment. Support for Konnect is new as of version 2.2.0.

Valid options for the *deployment* field are (in lowercase):
* enterprise
* konnect

Anything else will result in an error.

**Kong Enterprise**

            {
                "environment": "dr",
                "admin_api": "https://dr_admin_api:8001",
                "admin_token": "foobar",
                "deployment": "enterprise"
            }

New in 2.2 is the deployment field, as well as a rename from *admin_host* to *admin_api*. The deployment for Kong Enterprise is *enterprise* as seen in the example above.

**Kong Konnect**

            {
                "environment": "aws1",
                "admin_api" : "https://us.api.konghq.com/v2",
                "admin_token": "kpat_konnectaccesstoken",
                "deployment": "konnect",
                "control_plane_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   // optional -- See Konnect section below
            }    

The environment definition for Kong Konnect is slightly different than that for Kong Enterprise. The API now points to the Konnect API, and the token is the Konnect access token. The deployment field indicates Konnect, as expected. Finally, there is an optional *control_plane_id* field. If this field is specified, only services for that control plane will be retrieved and deduplicated; should the field not be present at all, all control planes the user has access to (including read-only access) will be retrieved and deduplicated.

**Discrete**

New as of KLCR 1.1, there is a section where you are able to provide "discreteness" between your API services. What this means is that if you have the same "discrete unit of programmatic functionality" in different environments (e.g., dev, prod, qa, and stage), and the upstream hosts are aptly named based on the environment they serve, KLCR will count those services as one. An example should help illustrate this.
    
    ┌──────────────────────┬──────────────────────────────────┐
    │Service Name          │Backend                           │
    ├──────────────────────┼──────────────────────────────────┤
    │dev-catfact-service   │ https://dev.catfact.ninja/fact   │
    │qa-catfact-service    │ https://qa.catfact.ninja/fact    │
    │stage-catfact-service │ https://stage.catfact.ninja/fact │
    │prod-catfact-service  │ https://prod.catfact.ninja/fact  │
    └──────────────────────┴──────────────────────────────────┘    

The four services above, irrespective of the Kong control planes (i.e., environments) where they are located, will be counted as 1 discrete service by KLCR.

### JQ

[jq](https://jqlang.github.io/jq/) is the tool that allows KLCR to do its magic. If you don't have jq installed, please do so or else you will render KLCR useless.

KLCR has been tested successfully with version **1.7.1** on MacOS 14.2.1, and Ubuntu 23.10. It is a known issue that jq version 1.6 does not work with KLCR; if you are on that version, please upgrade to 1.7.1 before proceeding.

## Running KLCR

Download [KLCR.sh](tools/klcr.sh) to your Mac or Linux machine, and make sure to change the permissions on the file:

    $ chmod +x klcr.sh

**IMPORTANT:** in order to get KLCR to return the most accurate results, you should run the following command in your Kong environments:

    $ kong migrations reinitialize-workspace-entity-counters

As the [docs](https://docs.konghq.com/gateway/latest/reference/cli/#kong-migrations) state, that command will reset the entity counters from the database entities. You should run this in every Kong environment specified in the input file at least once before running KLCR (once or multiple times). If it has been several months since you ran the command above, please do so before running KLCR.

You can get creative and add klcr.sh to your path if you'd like to make execution more flexible. Now take it for a drive:

    $ ./klcr.sh -i envs.json -o ./test

That it is. Assuming you used the example above, the output you will see on your terminal should be something like this:

    Environment   : prod
    Kong Version  : 2.8.4.9-enterprise-edition
    Admin API     : https://prod_admin_api_host:8001
    Gateway Status: Healthy
    Dev Portal    : Enabled
    ┌────────────────┬──────────────────┬───────────────────┐
    │Workspace       │Gateway Services  │Discrete Services  │
    ├────────────────┼──────────────────┼───────────────────┤
    │Engineering     │1                 │1                  │
    │WS1             │0                 │0                  │
    │WS2             │0                 │0                  │
    │WS3             │0                 │0                  │
    │default         │19                │17                 │
    │discrete        │4                 │1                  │
    │                │                  │                   │
    │Total           │24                │19 (x-workspace)   │
    └────────────────┴──────────────────┴───────────────────┘

    Environment   : dr
    Kong Version  : 2.8.4.9-enterprise-edition
    Admin API     : https://dr_admin_api_host:8001
    Gateway Status: Healthy
    Dev Portal    : Enabled
    ┌────────────────┬──────────────────┬───────────────────┐
    │Workspace       │Gateway Services  │Discrete Services  │
    ├────────────────┼──────────────────┼───────────────────┤
    │Engineering     │1                 │1                  │
    │WS1             │0                 │0                  │
    │WS2             │0                 │0                  │
    │WS3             │0                 │0                  │
    │default         │19                │17                 │
    │discrete        │4                 │1                  │
    │                │                  │                   │
    │Total           │24                │19 (x-workspace)   │
    └────────────────┴──────────────────┴───────────────────┘

    Environment   : aws1
    Deployment    : Konnect
    Admin API     : https://us.api.konghq.com/v2
    ┌──────────────────┬──────────────────┬──────────────────────┐
    │Control Planes    │Gateway Services  │Discrete Services     │
    ├──────────────────┼──────────────────┼──────────────────────┤
    │se-david-lamotta  │18                │16                    │
    │                  │                  │                      │
    │Total             │18                │16 (x-control-plane)  │
    └──────────────────┴──────────────────┴──────────────────────┘    

    SUMMARY
    ┌───────────────────┬──────────────────┬───────────────────┐
    │Kong Environments  │Gateway Services  │Discrete Services  │
    ├───────────────────┼──────────────────┼───────────────────┤
    │3                  │42                │34 (x-environment) │
    └───────────────────┴──────────────────┴───────────────────┘

The keen observer will notice that in this example the number of discrete services is 34. *dev* and *prod* are identical Kong Enterprise environments; *aws1* is a Konnect environment with 16 discrete services. KLCR is aggregating the number of environments (3), the number of gateway services (24 + 24 + 18), and the number of discrete services among the 3 environments (**34**). It is additionally worth mentioning that KLCR shows the number of discrete services across an individual Kong environment's workspaces (in Kong Enterprise) and control planes (in Konnect). We can see above that the *default* workspace has 19 gateway services, but out of those only 17 are discrete. The *discrete* workspace has the `https://[dev|qa|stage|prod].catfact.ninja/fact` service definitions, which count as 4 gateway services, but only as 1 discrete service.

The -o flag specifies a directory where all the license report files will be created.

So it is easier to share the output with others, you can compress the contents of the generated directory, and share a single file. Like this:

    $ ./klcr.sh -i envs.json -o ./test
    $ cd ./test
    $ zip test.zip *

To get to the help menu, you can execute the script like this:

    $ ./klcr.sh -h

## Under the Hood
What devil's magic is going on to make this work?--You might ask. Truth of the matter is that KLCR is leveraging publicly documented endpoints from the Kong Admin API, doing some iterations over the data collected, and then using jq to sort, count, and find unique strings.

If you are not familiar with the [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/), that is a good place to start so you can familiarize yourself with the endpoints used by KLCR. Since we are dealing with services per workspace, and services as a whole, the 3 Admin API endpoints used are:

1. [Listing workspaces](https://docs.konghq.com/gateway/api/admin-ee/latest/#/Workspaces/list-workspace)
2. [Listing services](https://docs.konghq.com/gateway/api/admin-ee/latest/#/Services/list-service)
3. [License report](https://docs.konghq.com/gateway/latest/licenses/report/#generate-a-license-report)

For Konnect, the [Konnect API ](https://docs.konghq.com/api/) is used. The main endpoints that are being used from Konnect are:

1. [Control Planes](https://docs.konghq.com/konnect/api/control-planes/latest/)
2. [Control Plane Services](https://docs.konghq.com/konnect/api/control-plane-configuration/latest/)

The logic behind the scenes is rather simple. As mentioned above, it consists of some loops to get all services in each workspace, build a master list of every service across all Kong environments, and then use jq to find the data we need. If you are curious about the number of Admin API calls made, that all depends on how many workspaces you have in each Kong cluster. You can do a cursory search for curl in [KLCR.sh](tools/KLCR.sh), and figure it out rather quickly.

KLCR is read-only as it relates to Kong; the source code is provided in efforts of full transparency, and the ability to modify if needed.

## Question or Feedback

KLCR is in its infancy. If you have suggestions for improvements or run into any trouble executing KLCR, please contact your Kong account team (Account Executive or Customer Success Manager) for assistance. Alternatively, you may open an issue directly here GitHub for future consideration--all feedback is welcome!

## Disclaimer

KLCR it **NOT** a Kong product, nor is it supported by Kong. This script is only made available to help understand the sprawl (if any) of duplicate services in a user's Kong environment.
