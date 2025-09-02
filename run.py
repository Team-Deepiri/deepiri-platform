
# The remainder of the environment can be generated
import os
import requests
import json
import utils_docker
NETWORK_NAME = "jaxk"
current_dir = os.path.dirname(os.path.abspath(__file__))
webapp_dir = os.path.join(current_dir, "client")

print("Making sure the Docker network is up")
utils_docker.ensure_network(NETWORK_NAME)

jaxk_client = dict(
    image="node:23",
    detach=True,  # Runs the container in detached mode
    name=f"jaxk_client",
    network=NETWORK_NAME,
    restart_policy={"Name": "always"},
    volumes={
        webapp_dir: {"bind": "/usr/src/app", "mode": "rw"},
        # "dist_volume": {"bind": "/usr/src/app/dist", "mode": "rw"},
    },
    working_dir="/usr/src/app",
    environment={
        "NODE_ENV": "development",
        "REACT_APP_API_URL": "http://jaxk_server:5000",
        "PORT": "5173"
    },
    command=(
        'sh -c "'
        "npm install && "
        "npm run dev\""
    ),
    ports={
        "5173/tcp": 5173
    },
    # user=uid,
    # group_add=[gid],
)

jaxk_server = dict(
    image="node:23",
    name="jaxk_server",
    volumes={
        os.path.join(current_dir, "server"): {"bind": "/app", "mode": "rw"},  # Named volume with bind info
    },
    network="jaxk",
    restart_policy={"Name": "always"},
    detach=True,
    command=["node", "/app/server.js"],
)


utils_docker.run_container(jaxk_client)
utils_docker.run_container(jaxk_server)
