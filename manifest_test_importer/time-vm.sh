#!/bin/bash

VM_FILE="vm-test.yaml" # <--- METTI IL NOME DEL TUO FILE QUI
VM_NAME="debian-test-vm"

# 1. Applica il manifest per essere sicuri che la risorsa esista
echo "Applying VM manifest..."
kubectl apply -f $VM_FILE

# 2. Spegni la VM per resettare il test (se era già accesa)
echo "Resetting VM state..."
kubectl patch vm $VM_NAME --type merge -p '{"spec":{"running":false}}'

# Attendi che la VMI (l'istanza attiva) sparisca del tutto
echo "Waiting for previous instance to cleanup..."
while kubectl get vmi $VM_NAME &>/dev/null; do sleep 1; done

echo "--- Starting Boot Timer Now ---"
START_TIME=$(date +%s)

# 3. Accensione
kubectl patch vm $VM_NAME --type merge -p '{"spec":{"running":true}}'

# 4. Loop di monitoraggio
echo "Monitoring Phase..."
while true; do
    PHASE=$(kubectl get vmi $VM_NAME -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$PHASE" == "Running" ] && [ -z "$RUN_TIME" ]; then
        RUN_TIME=$(date +%s)
        echo ">> VM reached Running phase in $((RUN_TIME - START_TIME))s"
    fi

    # Controlliamo se è 'Ready' (OS caricato)
    READY=$(kubectl get vmi $VM_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$READY" == "True" ]; then
        END_TIME=$(date +%s)
        break
    fi
    sleep 0.5
done

echo "------------------------------------------"
echo "FINAL BOOT TIME: $((END_TIME - START_TIME)) seconds"
echo "------------------------------------------"