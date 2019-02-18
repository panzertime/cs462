# How To Run the SPA

I designed this to work with, say, the Python simple HTTP server, like so:
```
python -m http.server 8000 --directory www/
```
if Python 3 is available, 
```
cd www && python -m SimpleHTTPServer 8000
```
if only Python 2 is available (upgrade! python2 is almost EOL!)

Use `python --version` to discover which you have installed.
