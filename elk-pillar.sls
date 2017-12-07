elastic:
  htpasswd: |
    admin:{SHA}<read $file after running 'htpasswd -c -s file username'>
kibana:
  bind_host: 172.17.1.56
