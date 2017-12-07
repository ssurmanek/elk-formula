elastic_repos_key:
  cmd.run:
    - name: wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

{% for soft, repo in {
  'elasticsearch': 'https://artifacts.elastic.co/packages/5.x/debian',
  'logstash': 'https://artifacts.elastic.co/packages/5.x/debian',
  }.items() %}
{{ soft }}_repo:
  file.managed:
    - name: /etc/apt/sources.list.d/{{ soft }}.list
    - require:
      - cmd: elastic_repos_key
    - contents: deb {{ repo }} stable main

{% endfor %}

{% set kibana_port = salt['pillar.get']('kibana:httpport', '8080') %}
{% set elastic_port = salt['pillar.get']('elasticsearch:httpport', '9200') %}
{% set server_name = salt['pillar.get']('kibana:site_name', 'kibana.cdp') %}
{% set wwwhome = salt['pillar.get']('kibana:wwwhome', '/var/www') %}
{% set kibana_wwwroot = wwwhome + '/' + server_name + '/' %}
{% set elastic_htpasswd_file = '/etc/nginx/elastic_passwd' %}
{% set bind_host = salt['pillar.get']('kibana:bind_host', '127.0.0.1') %}

elasticsearch_soft:
  pkg.installed:
    - name: elasticsearch
    - require:
      - file: elasticsearch_repo

logstash_soft:
  pkg.installed:
    - name: logstash
    - require:
      - file: logstash_repo
      - pkg: elasticsearch

kibana_static_dir:
  file.directory:
    - name: {{ kibana_wwwroot }};
    - user: www-data
    - group: www-data
    - makedirs: True

nginx_sites_dir:
  file.directory:
    - name: /etc/nginx/sites-enabled
    - makedirs: True

kibana_config_js:
  file.managed:
    - name: '{{ kibana_wwwroot }}/config.js'
    - template: jinja
    - source: salt://kibana/config.js
    - context:
       kibana_port: {{ elastic_port }}
       bind_host: {{ bind_host }}

elastic_htpasswd:
  file.managed:
    - name: {{ elastic_htpasswd_file }}
    - contents_pillar: elastic:htpasswd
    - group: www-data
    - mode: 640

elastic_conf:
  file.managed:
    - name: '/etc/elasticsearch/elasticsearch.yml'
    - contents: |+
          network.bind_host: {{ bind_host }}
    - mode: 644
    - require:
      - file: elasticsearch_repo

elastic_service:
  pkg.installed:
    - name: elasticsearch
    - require:
      - file: elastic_conf
  service.running:
    - name: elasticsearch
    - enable: True
    - watch:
      - file: elastic_conf
    - require:
      - pkg: elasticsearch

logstash_service:
  pkg.installed:
  - name: logstash
  - require:
    - file: logstash_repo
    - service: elasticsearch
  service.running:
    - name: logstash
    - enable: True

nginx_static_site:
  pkg.installed:
    - name: nginx
    - require:
      - file: nginx_sites_dir
      - file: kibana_static_dir
      - file: elastic_htpasswd

  service.running:
    - name: nginx
    - reload: True
    - enable: True
    - watch:
      - file: nginx_static_site
    - require:
      - service: elasticsearch

  file.managed:
    - template: jinja
    - source: salt://kibana/nginx_kibana_site
    - name: /etc/nginx/sites-enabled/kibana
    - mode: 644
    - context:
       kibana_port: {{ kibana_port }}
       server_name: {{ server_name }}
       kibana_wwwroot: {{ kibana_wwwroot }}
       elastic_htpasswd_file: {{ elastic_htpasswd_file }}

kibana:
  archive.extracted:
    - name: {{ kibana_wwwroot }}
    - source: https://artifacts.elastic.co/downloads/kibana/kibana-5.6.1-linux-x86_64.tar.gz
    - archive_format: tar
    - options: xf
    - source_hash: 'sha512=0228487f486ea2b3d68d6d493c4ae0d23c7317fa690c723c8fb2e0b150d095e71a6411d08a01e2da5e37e0f3ae2d7f9b6d8f0807116b93f8773649b83f7f4b8c'
