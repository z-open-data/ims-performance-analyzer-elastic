# IMS Performance Analyzer Sample Docker Container

This software package, `imspa-docker-elastic`, provides a [Docker](https://www.docker.com/products/overview) container that presents [Kibana](https://www.elastic.co/products/kibana) dashboards for analyzing operations logs from IBM z/OS mainframes.

The operations logs consist of various record types, from the following z/OS subsystems:
* IMS

The data used in the construction of these dashboards was streamed from z/OS into Elasticsearch, using [IMS Performance Analyzer for z/OS](https://www.ibm.com/support/pages/node/6263127)
("IMS PA").

The container provides a quick and easy way to try the dashboards in a self-contained "sandbox" environment, separate from any other instance of Elastic.

## Prerequisites

[Docker](https://www.docker.com/products/overview) is the only prerequisite.

Download and install Docker for your platform.

Execute `copy_objects.sh` script to copy all necessary objects to coresponding folders:

```sh
bash copy_objects.sh
```

## Loading or building the Docker image

Before you can start a Docker container, you need an image on which to base the container.

Build the image from the included Dockerfile:

```sh
docker build -t imspa-elastic .
```

(The trailing period is required.)

This `docker build` command uses the Dockerfile in the current directory to build an image and then load it into your repository. You can refer to the image using the tag `imspa-elastic`.

Building the image involves downloading resources from the web, which might take a few minutes.

When the image is in the repository you can use it to run many containers. You don't need to build the image again.

## Starting the container

Enter the following command to start the container:

```sh
docker run --rm -p 15601:5601 -p 19200:9200 -v "$(pwd):/volume" -v "elastic-data:/var/lib/elasticsearch" --name imspa-elastic imspa-elastic
```

Windows users: If you enter this command at a Windows command prompt (`cmd.exe`, rather than PowerShell), replace `$(pwd)` with `%cd%`

This `docker run` command:

* Starts a container named `imspa-elastic` (feel free to use a different name) based on the image `imspa-elastic`
* Exposes the Kibana port, 5601, as port 15601 on the host (your computer)
* Exposes the Elasticsearch HTTP API port, 9200, as host port 19200
* Shares the current directory as `/volume` inside the container
* Names the volume in which the container stores Elasticsearch's data `elastic-data`.

If container fails to start with the message `max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]` it means that the host's limits on mmap counts must be set to at least 262144.

Enter the following command to adjust mmap counts:

```sh
sudo sysctl -w vm.max_map_count=262144
```

And try starting the container again.

Another error that might occur is `max file descriptors [4096] for elasticsearch process is too low, increase to at least [65536]`. In this case, the host's limits on open files (as displayed by `ulimit -n`) must be increased (see [File Descriptors](https://www.elastic.co/guide/en/elasticsearch/reference/current/file-descriptors.html) in Elasticsearch documentation); and Docker's ulimit settings must be adjusted, either for the container (using `docker run`'s `--ulimit` option or Docker Compose's ulimits configuration option) or globally (e.g. in `/etc/sysconfig/docker`, add `OPTIONS="--default-ulimit nofile=1024:65536"`).

In this case `docker run` command will look like this:

```sh
docker run --rm --ulimit nofile=65535:65535 -p 15601:5601 -p 19200:9200 -v "$(pwd):/volume" -v "elastic-data:/var/lib/elasticsearch" --name imspa-elastic imspa-elastic
```

**&#x2139;** The `docker ps` command lists running containers, `docker stop` stops them, and `docker rm` removes them.

For more information about Docker commands, see the [Docker documentation](https://docs.docker.com/engine/reference/run/).

The first time you start the container, it performs first-start initialization to install dashboards and sample data. If you later start another container using the same volume, the first-start initialization will not occur (because data already exists).

If successful, the `docker run` command responds with the container ID, which is a string of hexadecimal digits.

Once the image has started, ongoing logs from Elasticsearch, Logstash, and Kibana will be displayed. If you used the sample run command above, you can browse to Kibana at [http://localhost:15601](http://localhost:15601).

## Configuring the container

The container extends the `sebp/elk` Docker image with additional functionality. You can read more about the `sebp/elk` Docker image at the [documentation](http://elk-docker.readthedocs.io/), [Docker Hub page](https://hub.docker.com/r/sebp/elk/), and [GitHub repository](https://github.com/spujadas/elk-docker).

### Environmental variables

When running the container for the first time, it is possible to use environmental variables to control the loading of sample data. These variables are in addition to the environmental variables provided by the base `sebp/elk` image (see the documentation for that image for more information).

There are several environmental variables which control the loading of data, index patterns, and other Kibana objects:

* `INSTALL_SAMPLES`: Defaults to `1`. Set to `0` and omit all other variables to disable all loading.
* `INSTALL_SAMPLE_DATA`: Defaults to `INSTALL_SAMPLES`. Set to `0` to skip loading the sample data into the image, or set to `1` to force loading of the sample data (when `INSTALL_SAMPLES` is `0`).
* `INSTALL_SAMPLE_OBJECTS`: Defaults to `INSTALL_SAMPLES`. Set to `0` to skip the loading of sample Kibana searches, visualizations, and dashboards. Set to `1` to force loading of Kibana objects (when `INSTALL_SAMPLES` is set to `0`).

If `INSTALL_SAMPLES` or `INSTALL_SAMPLE_OBJECTS` is `1` or not set, the default index pattern will be installed. Otherwise, the default index pattern will not be installed.

These environmental variables can be set on the Docker `run` command line using the `-e` flag:
```sh
docker run --rm -p 15601:5601 -p 19200:9200 -v "$(pwd):/volume" -v "elastic-data:/var/lib/elasticsearch" --name imspa-elastic -e FILL_SAMPLES=0 imspa-elastic
```

Using these variables, portions of the supplied samples can be selectively installed. Please note that if you disable installation of the data but permit setting of the default index pattern Kibana will not function correctly until an index matching the default pattern (`imspa-*`) exists in Elasticsearch.

### Persistent data volume

This container stores it's Elasticsearch data in a data volume, which can be persisted across container instances. The sample run command given above names this volume `elastic-data`. For more information on how this container uses volumes, see the [documentation](http://elk-docker.readthedocs.io/) for the `sebp/elk` Docker image this container extends.

## Loading data into the container

Logstash inside the container is configured to listen for JSON lines over TCP, on port 5046. You can use IMS PA to stream data to the container, or you can use a utility such as `netcat` to upload a JSON-lines file.

## Disclaimer

This repository is not supported by IBM.
