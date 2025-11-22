#!/bin/bash

################################################################################
# Script: visualize-switchover.sh
# Descripción: Muestra visualmente el switcheo en diagrama ASCII
# Uso: ./scripts/visualize-switchover.sh
# Propósito: Explicar conceptualmente cómo funciona Blue-Green
################################################################################

# Colores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║          🔵 BLUE-GREEN DEPLOYMENT ARCHITECTURE 🟢                     ║
║                    Interactive Visualization                           ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}State 1: BLUE is Active${NC}"
echo -e "${MAGENTA}═══════════════════════${NC}"
echo ""

cat << 'EOF'
                        👥 Users
                         │
                         ▼
                    ┌─────────────┐
                    │   Nginx     │
                    │ Port 80     │
                    └──────┬──────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼ ← ACTIVE (receives traffic)     ▼
    ┌──────────────┐              ┌──────────────┐
    │ 🔵 BLUE      │              │ 🟢 GREEN     │
    │ Port 3001    │              │ Port 3002    │
    │ v1.2.3       │              │ v1.1.0       │
    │ RUNNING ✓    │              │ RUNNING ✓    │
    └──────────────┘              └──────────────┘
    
    Nginx Config:
    upstream blue_backend {
        server 127.0.0.1:3001;
    }
    location / {
        proxy_pass http://blue_backend;
    }
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                      THE SWITCHOVER PROCESS                           ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}Phase 1: Prepare New Environment${NC}"
echo -e "${MAGENTA}════════════════════════════════${NC}"
echo ""

cat << 'EOF'
                     Deploy new version to GREEN:
                     
    Docker Hub ──→ Pull Image v1.3.0 ──→ 🟢 GREEN (Port 3002)
                                         ✓ Start Container
                                         ✓ Run Health Check
                                         ✓ Ready!

                        👥 Users (still using BLUE)
                         │
                         ▼
                    ┌─────────────┐
                    │   Nginx     │
                    │ Port 80     │
                    └──────┬──────┘
                           │
    ┌────────────────┬─────┴─────┬────────────────┐
    │                │                           │
    ▼ ← ACTIVE       ▼ ← STANDBY NEW               ▼
🔵 BLUE (3001)    🟢 GREEN (3002)          (NEW)
v1.2.3            v1.3.0
RUNNING ✓         RUNNING ✓ (ready, not receiving traffic)
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                    SWITCHING TRAFFIC (THE MAGIC)                      ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}Phase 2: Atomic Switch${NC}"
echo -e "${MAGENTA}════════════════════${NC}"
echo ""

echo -e "${YELLOW}STEP 1: Update Nginx Configuration${NC}"
echo ""
cat << 'EOF'
    /etc/nginx/conf.d/service.conf
    
    BEFORE:
    ┌─────────────────────────────────────┐
    │ upstream blue_backend {             │
    │     server 127.0.0.1:3001;          │
    │ }                                   │
    │ location / {                        │
    │     proxy_pass http://blue_backend; │
    │ }                                   │
    └─────────────────────────────────────┘
    
             ↓↓↓ cp green.conf service.conf ↓↓↓
    
    AFTER:
    ┌─────────────────────────────────────┐
    │ upstream green_backend {            │
    │     server 127.0.0.1:3002;          │
    │ }                                   │
    │ location / {                        │
    │     proxy_pass http://green_backend;│
    │ }                                   │
    └─────────────────────────────────────┘
EOF

echo ""
echo -e "${YELLOW}STEP 2: Validate New Configuration${NC}"
echo ""
cat << 'EOF'
    $ nginx -t
    nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    nginx: configuration test is successful
    ✓ Configuration valid!
EOF

echo ""
echo -e "${YELLOW}STEP 3: Reload Nginx (ZERO DOWNTIME)${NC}"
echo ""
cat << 'EOF'
    $ sudo systemctl reload nginx
    
    ⚠️  Key Point: reload ≠ restart
        - Restart = Stop all → Start = DOWNTIME ✗
        - Reload  = Reload config gracefully = NO DOWNTIME ✓
    
    Master process:
    1. Read new configuration
    2. Spawn NEW worker with new config
    3. Gracefully shutdown OLD worker
    4. New worker is ready
    
    Result: 👥 Users don't even notice!
    
    Time to switch: < 1 second ⚡
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                        AFTER SWITCH STATE                             ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}State 2: GREEN is Now Active${NC}"
echo -e "${MAGENTA}═════════════════════════════${NC}"
echo ""

cat << 'EOF'
                        👥 Users
                         │
                         ▼
                    ┌─────────────┐
                    │   Nginx     │
                    │ Port 80     │
                    └──────┬──────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼ ← NEW ACTIVE!                   ▼
    ┌──────────────┐              ┌──────────────┐
    │ 🔵 BLUE      │              │ 🟢 GREEN     │
    │ Port 3001    │              │ Port 3002    │
    │ v1.2.3       │              │ v1.3.0       │
    │ RUNNING ✓    │              │ RUNNING ✓    │
    │ (Standby)    │              │ (Active)     │
    └──────────────┘              └──────────────┘
         ↑ Ready for rollback      ↑ Receiving traffic
    
    Nginx Config (NOW):
    upstream green_backend {
        server 127.0.0.1:3002;
    }
    location / {
        proxy_pass http://green_backend;
    }

    📊 Traffic Pattern:
    All requests (100%) → Nginx → GREEN (3002)
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                  ROLLBACK (IF SOMETHING FAILS)                        ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}Emergency: GREEN has issues${NC}"
echo -e "${MAGENTA}═════════════════════════════${NC}"
echo ""

cat << 'EOF'
    $ ./scripts/switch-to-blue.sh
    
    ▶ Backup current config
    ▶ Copy blue.conf → service.conf
    ▶ Test nginx configuration
    ▶ Reload nginx
    
    💨 Time: < 1 second!

                        👥 Users
                         │
                         ▼
                    ┌─────────────┐
                    │   Nginx     │
                    │ Port 80     │
                    └──────┬──────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼ ← BACK TO BLUE (Rollback!)     ▼
    ┌──────────────┐              ┌──────────────┐
    │ 🔵 BLUE      │              │ 🟢 GREEN     │
    │ Port 3001    │              │ Port 3002    │
    │ v1.2.3       │              │ v1.3.0       │
    │ RUNNING ✓    │              │ RUNNING ✓    │
    │ (Active)     │              │ (Standby)    │
    └──────────────┘              └──────────────┘
         ↑ Back in production!

    Result: Users see v1.2.3 again (backup still running)
    Impact: Minimal, instant recovery
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                  KEY DIFFERENCES: TRADITIONAL vs BLUE-GREEN            ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${RED}❌ TRADITIONAL DEPLOYMENT${NC}"
echo ""
cat << 'EOF'
    1. Stop current service      ━━━ DOWNTIME STARTS
    2. Deploy new version
    3. Start new service         ━━━ DOWNTIME ENDS
    4. If error: restore backup
    
    Downtime: Minutes
    Rollback: Complex, slow
    Risk: High
    
    Timeline:
    ─────────────────────────────────────
    Normal │ DOWNTIME │ New Version │ Rollback?
EOF

echo ""
echo -e "${GREEN}✅ BLUE-GREEN DEPLOYMENT${NC}"
echo ""
cat << 'EOF'
    1. Deploy to BLUE (standby)
    2. Test in BLUE
    3. Switch Nginx to BLUE      ━━━ < 1 second, NO downtime
    4. If error: Switch back
    
    Downtime: 0 seconds
    Rollback: Instant (< 1 sec)
    Risk: Very Low
    
    Timeline:
    ─────────────────────────────────────
    GREEN Active │ Deploy to BLUE │ SWITCH │ BLUE Active
                (testing)                   (or rollback)
EOF

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                    REAL-WORLD USAGE                                   ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${MAGENTA}Companies Using Blue-Green:${NC}"
echo ""
cat << 'EOF'
    🎬 Netflix
       - Millions of users
       - Zero downtime is CRITICAL
       - Uses Blue-Green constantly
    
    🔴 Amazon
       - Prime members watching
       - Cannot afford downtime
       - Uses variations of this pattern
    
    🔵 Facebook
       - Billions of users
       - Deploys multiple times per day
       - Blue-Green variations
    
    🟦 Microsoft
       - Azure cloud
       - Official recommendation
       - Built-in support
EOF

echo ""
echo -e "${CYAN}"
cat << 'EOF'
Why? Because in production:

    → Downtime = Lost customers
    → Downtime = Lost revenue
    → Downtime = Lost trust
    → Blue-Green = Zero downtime = Success ✓
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

clear
echo -e "${CYAN}"
cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                         SUMMARY                                       ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

cat << 'EOF'

    🔵🟢 BLUE-GREEN DEPLOYMENT

    ✓ Two identical production environments
    ✓ Nginx routes traffic to active one
    ✓ Switch is atomic and instantaneous
    ✓ Old environment stays running (rollback)
    ✓ Zero downtime deployment
    ✓ Used by Netflix, Amazon, Facebook, Microsoft
    
    Architecture:
    ─────────────
    Nginx (Load Balancer)
      ├─ 🔵 BLUE (Production or Standby)
      └─ 🟢 GREEN (Production or Standby)
    
    Switching:
    ──────────
    1. Deploy new version to standby
    2. Update Nginx configuration
    3. Reload Nginx (< 1 second)
    4. Done! Traffic now on new version
    
    Rollback:
    ─────────
    1. Update Nginx configuration back
    2. Reload Nginx (< 1 second)
    3. Done! Back to previous version
    
    Benefits:
    ─────────
    • Zero downtime
    • Instant rollback
    • No lost requests
    • Gradual testing (before switch)
    • Production safe
    • Industry standard

    Demo Commands:
    ──────────────
    ./scripts/status-check.sh           # See current state
    ./scripts/show-switchover.sh blue   # Demo switch
    ./scripts/show-switchover.sh green  # Demo switch
    
    Result: 
    ───────
    Professional, zero-downtime deployments
    Production-ready DevOps pattern
    Industry best practice demonstrated

EOF

echo -e "${GREEN}"
cat << 'EOF'

    🎓 Now you understand Blue-Green Deployment!
    🚀 Ready to show your professor?
    ⭐ This is how the big companies do it!

EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}Visualization complete!${NC}"
echo ""
