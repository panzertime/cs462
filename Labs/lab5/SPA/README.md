# How To Run the SPA

I designed this to work with, say, the Python simple HTTP server, like so:
```
python -m http.server 8000 --directory www/
```
if Python 3 is available.
If only Python 2 is available (upgrade! python2 is almost EOL!), try:
```
cd www && python -m SimpleHTTPServer 8000
```

Use `python --version` to discover which you have installed.

## Host and Port
I have hardcoded Sky Cloud and Event URIs in my SPA. Check the variables near the top of `index.html` in `www`. You will need to change these to use this SPA with another set of picos.