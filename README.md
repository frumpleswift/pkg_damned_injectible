# pkg_damned_injectible
This package contains a variety of methods vulnerable to SQL injection.  With the exception of pkg_damned_injectible.boring_select, the injection techniques are intended to be non-trivial.  Most will not even register with sqlmap.

The package is built using Oracle built in htp packages, and requires an Oracle HTTP server, or Apache server configured with the modowa module to function.  
