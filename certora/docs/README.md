# Installing and using Certora Documentation

## Quickstart
To build the files locally.

1. In a clean Python virtual environment, run from the repositories root:
```bash
pip3 install -r certora/docs/requirements.txt
```
2. In the same environment run:
```bash
sphinx-build -b html certora/docs/source/ certora/docs/build/html -t is_dev_build
```
3. The built html docs index file is in `certora/docs/build/html/index.html` and
   you can view it in your browser.
   
## More information
More information can be found in
[Certora docs infrastructure](https://certora-docs-infrastructure.readthedocs-hosted.com/_/sharing/Unn4mEMhjhx9sxC7oNLRT98AfX1s0k4u?next=/en/latest/).
