# Custom pgAdmin image with dependency fixes and auto-configured PostgreSQL server
FROM dpage/pgadmin4:latest

# Copy requirements file and server configuration
COPY requirements.txt /tmp/requirements.txt
COPY servers.json /pgadmin/servers.json
COPY entrypoint.sh /pgadmin/entrypoint.sh

USER root

# Install dependency fixes from requirements.txt at BUILD TIME (not runtime)
# This prevents startup delays and fixes the root cause of warnings
# pgAdmin uses /venv/bin/pip in the base image
RUN if [ -f /venv/bin/pip ]; then \
        /venv/bin/pip install --no-cache-dir --upgrade -r /tmp/requirements.txt; \
    elif [ -f /usr/local/bin/pip3 ]; then \
        /usr/local/bin/pip3 install --no-cache-dir --upgrade -r /tmp/requirements.txt; \
    elif command -v pip3 > /dev/null; then \
        pip3 install --no-cache-dir --upgrade -r /tmp/requirements.txt; \
    fi || true

# Make entrypoint script executable
RUN chmod +x /pgadmin/entrypoint.sh

USER pgadmin

# Set PYTHONWARNINGS to suppress any remaining warnings from dependencies
# Format: action:message:category:module:line
# - passlib.pwd: UserWarning about pkg_resources deprecation
# - sshtunnel: SyntaxWarning (should be fixed by upgrade, but suppress as fallback)
ENV PYTHONWARNINGS="ignore::UserWarning:passlib.pwd,ignore::SyntaxWarning"

# Use custom entrypoint
ENTRYPOINT ["/pgadmin/entrypoint.sh"]

