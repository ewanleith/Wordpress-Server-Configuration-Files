# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
# 
# Default backend definition.  Set this to point to your content
# server.
# 
backend default {
    .host = "127.0.0.1";
    .port = "8080";
	.connect_timeout = 600s;
	.first_byte_timeout = 600s;
	.between_bytes_timeout = 600s;
	.max_connections = 800;
}


acl purge {
        "localhost";
}

sub vcl_recv {
	set req.grace = 2m;

  # Set X-Forwarded-For header for logging in nginx
  remove req.http.X-Forwarded-For;
  set    req.http.X-Forwarded-For = client.ip;


  # Remove has_js and CloudFlare/Google Analytics __* cookies.
  set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
  # Remove a ";" prefix, if present.
  set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");



# Either the admin pages or the login
if (req.url ~ "/wp-(login|admin|cron)") {
        # Don't cache, pass to backend
        return (pass);
}


# Remove the wp-settings-1 cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-1=[^;]+(; )?", "");

# Remove the wp-settings-time-1 cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-time-1=[^;]+(; )?", "");

# Remove the wp test cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wordpress_test_cookie=[^;]+(; )?", "");

# Static content unique to the theme can be cached (so no user uploaded images)
# The reason I don't take the wp-content/uploads is because of cache size on bigger blogs
# that would fill up with all those files getting pushed into cache
if (req.url ~ "wp-content/themes/" && req.url ~ "\.(css|js|png|gif|jp(e)?g)") {
    unset req.http.cookie;
}

# Even if no cookies are present, I don't want my "uploads" to be cached due to their potential size
if (req.url ~ "/wp-content/uploads/") {
    return (pass);
}

# Check the cookies for wordpress-specific items
if (req.http.Cookie ~ "wordpress_" || req.http.Cookie ~ "comment_") {
        # A wordpress specific cookie has been set
    return (pass);
}



	# allow PURGE from localhost
	if (req.request == "PURGE") {
		if (!client.ip ~ purge) {
			error 405 "Not allowed.";
		}
		return (lookup);
	}


	# Force lookup if the request is a no-cache request from the client
	if (req.http.Cache-Control ~ "no-cache") {
		return (pass);
	}


# Try a cache-lookup
return (lookup);

}

sub vcl_fetch {
	#set obj.grace = 5m;
    set beresp.grace = 2m;

}

sub vcl_hit {
        if (req.request == "PURGE") {
                purge;
                error 200 "Purged.";
        }
}

sub vcl_miss {
        if (req.request == "PURGE") {
                purge;
                error 200 "Purged.";
        }
}
