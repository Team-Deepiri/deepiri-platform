# Custom pgAdmin image with setuptools pinned to avoid pkg_resources deprecation warning
FROM dpage/pgadmin4:latest

# Pin setuptools to version < 81 to avoid pkg_resources deprecation warning
# This is a temporary fix until passlib updates to use importlib.metadata instead
USER root

# Find and downgrade setuptools - try multiple Python/pip locations
RUN if [ -f /venv/bin/pip ]; then \
        /venv/bin/pip install --no-cache-dir --upgrade 'setuptools<81'; \
    elif [ -f /usr/local/bin/pip3 ]; then \
        /usr/local/bin/pip3 install --no-cache-dir --upgrade 'setuptools<81'; \
    elif command -v pip3 > /dev/null; then \
        pip3 install --no-cache-dir --upgrade 'setuptools<81'; \
    fi || true

USER pgadmin

# Set PYTHONWARNINGS to suppress the deprecation warning from passlib
# Format: action:message:category:module:line
ENV PYTHONWARNINGS="ignore::UserWarning:passlib.pwd"

