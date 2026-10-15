# Walkthrough - Fase 2: Infrastructure as Code (OpenTofu) & Studiestof

In deze fase hebben we de technische architectuur uit het Keuzedocument omgezet naar werkende, modulaire **Infrastructure as Code (IaC)** met **OpenTofu** (de open-source vork van Terraform, MPL 2.0 licentie). Alle code is gevalideerd (`tofu validate` = **Success! The configuration is valid.**).

---

## 1. Overzicht van de Gecreëerde Codebase

Alle code staat in de map [`infra/`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/):

```
infra/
├── versions.tf                     # OpenTofu v1.12+ specificaties & AWS Provider v5.100
├── variables.tf                    # Projectvariabelen (regio, CIDR's, instance types, credentials)
├── terraform.tfvars                # Concreet configuratiebestand voor Innovatech Solutions
├── outputs.tf                      # Output variabelen (ALB Public URL, DB endpoint, VPC IDs)
├── main.tf                         # Root orchestratie die alle 4 modules aan elkaar koppelt
│
└── modules/
    ├── networking/                 # REQ-01: 3 VPC's, 6 Subnets, IGW, NAT GW, Peering & Routing
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── security/                   # REQ-02: Zero-Trust Security Groups Matrix
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── compute/                    # REQ-03, 04, 09: ALB, Launch Template, Rootless Podman, Spot ASG
    │   ├── main.tf
    │   ├── cloud-init.sh           # User-Data script voor Rootless Podman + cgroups v2 256MB
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── database/                   # REQ-02: Amazon RDS Multi-AZ MySQL (db.t3.micro)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 2. Canvas Studiestof & Technische Uitleg per Onderdeel

Hieronder vind je de directe koppeling tussen wat er in de code staat en de Canvas theorie uit **08 - MA-NCA - Period 1 - Content**:

### A. Netwerkinrichting & Segmentatie
* **Canvas Pagina:** [[Networking on AWS]] & [[Network Segmentation]]
* **Presentatie op Canvas:** `AWS Connecting Networks.pptx`
* **Wat staat er in de code?**
  * In [`modules/networking/main.tf`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/modules/networking/main.tf) bouwen we 3 gescheiden VPC's:
    1. **Hub VPC (`10.0.0.0/16`):** Bevat publieke subnets voor de Load Balancer en één centrale NAT Gateway, plus een management subnet voor de CI/CD runner.
    2. **Spoke 1 Web VPC (`10.1.0.0/16`):** Bevat uitsluitend private subnets voor de webservers.
    3. **Spoke 2 Data VPC (`10.2.0.0/16`):** Bevat uitsluitend private subnets voor de database.
* **Waarom doen we dit zo (Theorie)?**
  * *CIA-Triad (Confidentiality & Integrity):* Door de database in een aparte Spoke VPC te plaatsen zonder Internet Gateway, kan een aanvaller vanaf het internet nóóit direct bij de data komen.
  * *Non-transitieve VPC Peering:* We koppelen Hub <-> Web en Web <-> Data. We maken **geen** peering tussen Hub en Data. Omdat AWS VPC Peering niet transitief is, is de database fysiek onbereikbaar vanuit de Hub.
  * *FinOps Besparing:* VPC Peering heeft \$0,00 basiskosten. Hierdoor besparen we \$1.320,- per jaar t.o.v. AWS Transit Gateway.

---

### B. Zero-Trust Security Groups
* **Canvas Pagina:** [[Network Segmentation]] & [[Networking on AWS]]
* **Wat staat er in de code?**
  * In [`modules/security/main.tf`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/modules/security/main.tf) configureren we 4 specifieke Security Groups met een *implicit deny* principe:
    * `alb_sg`: Accepteert poort 443 en 80 vanaf `0.0.0.0/0`; stuurt door naar de Web Tier over poort 80.
    * `web_sg`: Accepteert poort 80 **uitsluitend** vanaf de Hub VPC (`10.0.0.0/16`); verstuurt MySQL queries (poort 3306) naar de Data VPC (`10.2.0.0/16`).
    * `db_sg`: Accepteert poort 3306 **uitsluitend** vanaf de Web Tier (`10.1.0.0/16`). **Heeft 0 uitgaande regels!**
    * `runner_sg`: Heeft 0 inkomende poorten; pollt uitgaand via HTTPS.
* **Waarom doen we dit zo (Theorie)?**
  * Security Groups werken op hypervisor-niveau (stateful firewall). Zelfs als iemand inbreekt op een server, kan deze niet communiceren op poorten die niet expliciet zijn gedefinieerd.

---

### C. Infrastructure as Code (IaC) met OpenTofu / Terraform
* **Canvas Pagina:** [[Infrastructure Provisioning with Terraform]]
* **Presentatie op Canvas:** `Terraform Intro`
* **Wat staat er in de code?**
  * Declaratieve HCL2 code opgedeeld in herbruikbare modules (`source = "./modules/..."`).
  * Invoer via `variables.tf` en `terraform.tfvars`, en uitvoer via `outputs.tf`.
  * Remote state management voorbereiding in `versions.tf` met S3 en DynamoDB state locking.
* **Waarom doen we dit zo (Theorie)?**
  * Voorkomt *Configuration Drift* (handmatige wijzigingen in de AWS console).
  * Maakt de hele omgeving met één commando reproduceerbaar in minuten (`tofu apply`), in plaats van dagen handmatig klikken.

---

### D. Compute, Rootless Podman & Kernel Cgroups
* **Canvas Pagina:** [[Container platforms]] & [[Containerization]]
* **Presentaties:** `Workshop_Containerplatformen_kiezen.pptx` & `Namespaces_en_Cgroups.pptx`
* **Wat staat er in de code?**
  * In [`modules/compute/cloud-init.sh`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/modules/compute/cloud-init.sh) start EC2 via cloud-init:
    1. Maakt een onbevoorrechte gebruiker `appuser` aan.
    2. Configureert Linux User Namespaces via `/etc/subuid` en `/etc/subgid`.
    3. Start een Nginx container met Rootless Podman en stelt de cgroups v2 geheugenlimiet in:  
       `podman run -d --name innovatech-web -p 80:80 --memory 256m ...`
* **Waarom doen we dit zo (Theorie & Docentfeedback de vakdocent)?**
  * *Geen Root Daemon:* De traditionele Docker daemon draait als root. Wie uitbreekt uit een Docker container, is direct root op de VM. Bij Rootless Podman draait de container onder `appuser`; een container-uitbraak geeft **geen root-toegang op de host**.
  * *REQ-09 Geheugenlimiet:* Met `--memory 256m` stelt Linux cgroups v2 (`/sys/fs/cgroup/memory.max`) een harde grens in. Dit voorkomt dat een gecrashte webserver de hele server platlegt.

---

### E. Elasticiteit, Spot Instances & Hoge Beschikbaarheid
* **Canvas Pagina:** [[Application Architecture. Design-for-Failure and Elasticity]] & [[AWS Connecting to and Core Services (EC2 and RDS)]]
* **Wat staat er in de code?**
  * In [`modules/compute/main.tf`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/modules/compute/main.tf):
    * `aws_autoscaling_group` met een `mixed_instances_policy`:
      * `on_demand_base_capacity = 2`: Garandeert een stabiele 24/7 Multi-AZ basis.
      * `on_demand_percentage_above_base_capacity = 0`: Alle extra servers tijdens de ticketverkoop zijn **AWS Spot Instances** (70–90% korting!).
    * Connection draining van 60 seconden op de Target Group om Spot-beëindigingen netjes op te vangen.
  * In [`modules/database/main.tf`](file:///home/emirozcan/Downloads/IT_Projects-20260825T101708Z-1-001/IT_Projects/SCHOOLBRAIN/infra/modules/database/main.tf):
    * `multi_az = true` op de Amazon RDS MySQL instance. Synchrone spiegeling naar een Standby node in AZ-b. Failover binnen 60 seconden ($RTO < 2\text{ min}$, $RPO \approx 0$).

---

## 3. Validatieresultaat

De code is lokaal getest en geverifieerd:
```bash
$ tofu validate
Success! The configuration is valid.
```
