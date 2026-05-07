# Stack de développement local

Reproduit la stack complète (OpenSearch, Logstash, HDFS, YARN) en mode single-node,
sans Kubernetes. Idéal pour le développement et les tests rapides.

## Démarrage rapide

```bash
# Depuis la racine du projet
cp .env.example .env
# Définir OPENSEARCH_INITIAL_ADMIN_PASSWORD dans .env

make dev          # démarre la stack
make dev-logs     # suit les logs
make dev-down     # arrête et supprime les volumes
```

## Ports exposés (localhost uniquement)

| Service                | Port  |
|------------------------|-------|
| OpenSearch API         | 9200  |
| OpenSearch Dashboards  | 5601  |
| Logstash Beats input   | 5044  |
| Logstash TCP/UDP input | 5000  |
| Logstash HTTP input    | 8080  |
| HDFS NameNode UI       | 9870  |
| HDFS RPC               | 8020  |
| YARN ResourceManager   | 8088  |

## Architecture des configurations

Les fichiers de configuration sont **montés depuis `config/`**, répertoire partagé
avec Kubernetes :

```
config/
├── logstash/
│   ├── logstash.yml      → monté par Docker ET généré en ConfigMap K8s
│   └── pipeline.conf     → idem (env vars pour ssl : LS_SSL_ENABLED)
└── hadoop/
    ├── core-site.xml     → monté par Docker (single-node)
    ├── hdfs-site-dev.xml → monté par Docker (réplication=1)
    ├── yarn-site-dev.xml → monté par Docker
    └── mapred-site.xml   → monté par Docker
```

**Modifier un fichier dans `config/` → répercuté dans les deux environnements.**

## Différences dev vs prod

| Paramètre          | Docker (dev)          | Kubernetes (prod)           |
|--------------------|-----------------------|-----------------------------|
| OpenSearch         | single-node, demo-certs | cluster 3 masters + 3 data |
| TLS HTTP           | désactivé             | activé (cert-manager)       |
| HDFS HA            | non (single-node)     | oui (2 NameNodes + ZK)      |
| YARN HA            | non                   | oui (2 ResourceManagers)    |
| Secrets            | `.env`                | Kubernetes Secrets          |
