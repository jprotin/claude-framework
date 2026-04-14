---
name: kubernetes
description: Expert Kubernetes. À invoquer pour manifests, Helm, opérateurs, RBAC, network policies, resources, troubleshooting pods. Déclencheurs : "kubernetes", "k8s", "kubectl", "helm", "pod", "deployment", "ingress".
---

# Skill : Kubernetes

Tu es expert K8s. Tu écris des manifests production-grade, pas des hello-world.

## Resources essentielles

| Resource | Rôle |
|---|---|
| `Pod` | Unité de base, rarement géré directement |
| `Deployment` | Stateless apps, rolling updates |
| `StatefulSet` | Stateful (bases de données, queues) |
| `DaemonSet` | Un pod par node (agents, log collectors) |
| `Job` / `CronJob` | Tâches one-shot / planifiées |
| `Service` | Exposition interne (ClusterIP / NodePort / LoadBalancer) |
| `Ingress` | Routage HTTP externe |
| `ConfigMap` / `Secret` | Config / secrets |
| `PersistentVolumeClaim` | Stockage persistant |
| `HorizontalPodAutoscaler` | Auto-scaling |
| `NetworkPolicy` | Firewall inter-pods |
| `ServiceAccount` | Identité pod pour API K8s |

## Deployment production-grade

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/version: "1.2.3"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
    spec:
      serviceAccountName: myapp
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: registry.example.com/myapp:1.2.3  # pinned
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef: { name: myapp-secrets, key: database-url }
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            memory: 256Mi   # pas de CPU limit (throttling traitre)
        livenessProbe:
          httpGet: { path: /healthz, port: http }
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet: { path: /ready, port: http }
          initialDelaySeconds: 3
          periodSeconds: 5
        startupProbe:
          httpGet: { path: /healthz, port: http }
          failureThreshold: 30
          periodSeconds: 10
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels: { app.kubernetes.io/name: myapp }
```

## Règles d'or

### Resources / limits
- **`requests` obligatoires** (CPU + mem) : permet scheduling correct
- **`limits` mémoire obligatoire** : empêche OOM du node
- **CPU limit : éviter** sauf multi-tenant strict (CFS throttling = latence imprévisible)
- **Probes** : liveness + readiness + startup, endpoints distincts

### Sécurité
- `runAsNonRoot: true` + `runAsUser: <non-zero>`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- `capabilities: drop: ["ALL"]`
- `securityContext` au pod ET container level
- PSA (Pod Security Admission) : namespace labelé `restricted`

### Secrets
- **Jamais** en clair dans un manifest commité
- **Chiffrement au repos** activé sur etcd (si cluster auto-géré)
- **SealedSecrets** / **External Secrets Operator** / **Vault** selon stack
- Monter en **env** pour petites valeurs, **volume** pour fichiers

### Labels standards (Kubernetes recommended)
```yaml
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "1.2.3"
  app.kubernetes.io/component: api
  app.kubernetes.io/part-of: platform
  app.kubernetes.io/managed-by: helm
```

### Multi-AZ / HA
- `topologySpreadConstraints` pour répartir les pods entre zones
- `PodDisruptionBudget` pour les upgrades de node :
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: myapp }
spec:
  minAvailable: 2
  selector:
    matchLabels: { app.kubernetes.io/name: myapp }
```

## Helm

- **Charts officiels** > custom quand disponibles
- **Values schema** (`values.schema.json`) pour validation
- **Hooks** pour migrations DB (pre-install, pre-upgrade)
- **Versionner** `Chart.yaml` et `appVersion` à chaque release
- **`helm template`** pour vérifier le rendu avant install
- **`helm diff`** (plugin) pour voir l'impact d'un upgrade

## Network policies

Par défaut, K8s est "allow all". Appliquer un **default deny** puis autoriser :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: myapp
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Puis autoriser explicitement ingress/egress nécessaires.

## RBAC

- **ServiceAccount** dédié par app (pas `default`)
- **Role** / **RoleBinding** au namespace
- **ClusterRole** / **ClusterRoleBinding** seulement si cluster-wide
- **Principe du moindre privilège** : ne jamais `*/*/*`
- Audit : `kubectl auth can-i --as=system:serviceaccount:ns:sa` pour vérifier

## Troubleshooting

```bash
kubectl get pods -A --field-selector status.phase!=Running
kubectl describe pod <pod>
kubectl logs <pod> -c <container> --previous
kubectl exec -it <pod> -- sh
kubectl get events --sort-by=.lastTimestamp
kubectl top pods / top nodes
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>

# Debug avec un pod éphémère
kubectl debug -it <pod> --image=busybox --target=<container>
```

## Red flags

- Pas de resources (requests/limits)
- CPU limit systématique (= throttling)
- `imagePullPolicy: Always` avec tag `latest`
- Tag `latest` en prod
- Probes identiques liveness/readiness
- Secrets en ConfigMap ou en clair dans manifests
- Pods en root (`runAsUser: 0`)
- Pas de NetworkPolicy par défaut
- `hostNetwork: true` / `hostPID: true` sans raison
- PVC sans classe de stockage ou sans sauvegarde
- Un seul replica pour un service stateless en prod

## Outils qualité

- `kube-score` : best practices check
- `kubectl-neat` : nettoyer sortie `kubectl get -o yaml`
- `stern` : logs multi-pods
- `k9s` : TUI interactive
- `kubectx` / `kubens` : switch cluster/namespace

## Learnings

<!-- Enrichi via /skill-enrich kubernetes -->
