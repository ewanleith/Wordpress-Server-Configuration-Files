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
}


sub vcl_fetch {
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

