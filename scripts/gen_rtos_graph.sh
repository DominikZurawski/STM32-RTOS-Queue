# #!/bin/bash
# set -e

# OUT_DIR=graphs/rtos
# DOT=$OUT_DIR/rtos.dot
# PNG=$OUT_DIR/rtos.png
# SRC="Core/Src Core/Inc"

# mkdir -p "$OUT_DIR"

# # --- Funkcja czyszcząca: usuwa rzutowania, &, spacje i znaki \r ---
# clean_name() {
#   tr -d '\r' | sed 's/(void\*)//g; s/&//g; s/[[:space:]]//g; s/(//g; s/)//g; s/;//g' | grep -v '^$' || true
# }

# # =================================================
# # COLLECT SYMBOLS
# # =================================================

# FILES=$(find Core/Src -name "*.c" -exec basename {} \; | clean_name | sort -u || true)
# TASKS=$(grep -RE "osThreadNew|xTaskCreate" $SRC 2>/dev/null | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name | sort -u || true)
# QUEUES=$(grep -RE "xQueueCreate" $SRC 2>/dev/null | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name | grep '^q_' | sort -u || true)
# QUEUE_USES=$(grep -RE "xQueueSend|xQueueReceive|xQueueSendFromISR" $SRC 2>/dev/null | grep -oE "q_[a-zA-Z0-9_]+" | sort -u || true)
# ISRS=$(grep -R "_IRQHandler" $SRC 2>/dev/null | sed -n 's/.*void \(.*_IRQHandler\).*/\1/p' | clean_name | sort -u || true)

# # =================================================
# # GRAPH HEADER
# # =================================================

# cat > "$DOT" <<EOF
# digraph RTOS {
#   rankdir=LR;
#   compound=true;
#   graph [
#     fontname="Helvetica", 
#     bgcolor="white", 
#     nodesep=0.15, 
#     ranksep=0.6, 
#     splines=spline,
#     concentrate=true,  # Przywrócone grupowanie dla czytelności q_print
#     overlap=false
#   ];
#   node [
#     fontname="Helvetica", 
#     style="filled,rounded", 
#     color="#333333", 
#     height=0.25, 
#     fontsize=10,
#     margin="0.1,0.05"
#   ];
#   edge [fontname="Helvetica", fontsize=8, arrowsize=0.6];
# EOF

# # =================================================
# # DEFINE ALL NODES (BEZ POMIJANIA)
# # =================================================

# # Zbieramy wszystkie unikalne nazwy plików użyte w kodzie, by uniknąć czarnych owali
# ALL_F=$(grep -rE "xQueue|osThread|_IRQHandler" $SRC 2>/dev/null | cut -d: -f1 | xargs -n1 basename | clean_name | sort -u)
# FILES_FINAL=$(echo -e "$FILES\n$ALL_F" | sort -u)

# for f in $FILES_FINAL; do
#   [ -n "$f" ] && echo "\"$f\" [label=\"$f\", shape=box, fillcolor=\"#eeeeee\"];" >> "$DOT"
# done

# for t in $TASKS; do
#   [ -n "$t" ] && echo "\"$t\" [label=\"Task: $t\", shape=box, fillcolor=\"#b6f2c2\"];" >> "$DOT"
# done

# ALL_QS=$(echo -e "$QUEUES\n$QUEUE_USES" | sort -u)
# for q in $ALL_QS; do
#   [ -n "$q" ] && echo "\"$q\" [label=\"Queue: $q\", shape=ellipse, fillcolor=\"#b7d7ff\"];" >> "$DOT"
# done

# for i in $ISRS; do
#   [ -n "$i" ] && echo "\"$i\" [label=\"$i\", shape=diamond, fillcolor=\"#ff9999\"];" >> "$DOT"
# done

# # =================================================
# # EDGES
# # =================================================

# # --- TASK CREATION ---
# grep -RE "osThreadNew|xTaskCreate" $SRC 2>/dev/null | while read -r line; do
#   F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
#   T=$(echo "$line" | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name)
#   # group=F sprawia, że plik i jego taski starają się być w tej samej linii poziomej
#   [ -n "$T" ] && echo "\"$F\" -> \"$T\" [color=\"#228b22\", style=dashed, group=\"$F\"];" >> "$DOT"
# done

# # --- QUEUE OPERATIONS ---
# # Sort -u usuwa duplikaty, by nie było 20 strzałek "send" do q_print
# grep -RE "xQueueSend\(|xQueueReceive|xQueueSendFromISR" $SRC 2>/dev/null | while read -r line; do
#   F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
#   Q=$(echo "$line" | grep -oE "q_[a-zA-Z0-9_]+" | head -1)
#   if [ -n "$Q" ]; then
#     if [[ "$line" == *"Receive"* ]]; then 
#       echo "\"$Q\" -> \"$F\" [label=\"recv\", color=\"#ff8c00\", labeldistance=1.2];"
#     elif [[ "$line" == *"FromISR"* ]]; then
#       echo "\"$F\" -> \"$Q\" [label=\"sendISR\", color=\"#b22222\"];"
#     else 
#       echo "\"$F\" -> \"$Q\" [label=\"send\", color=\"#2e8b57\"];"
#     fi
#   fi
# done | sort -u >> "$DOT"

# # --- ISR → FILE ---
# grep -R "_IRQHandler" $SRC 2>/dev/null | while read -r line; do
#   I=$(echo "$line" | sed -n 's/.*void \(.*_IRQHandler\).*/\1/p' | clean_name)
#   F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
#   [ -n "$I" ] && echo "\"$I\" -> \"$F\" [color=\"#b22222\"];" >> "$DOT"
# done

# # =================================================
# # LEGEND & CLOSE
# # =================================================

# cat >> "$DOT" <<EOF
#   subgraph cluster_legend {
#     label="Legend"; style=dashed; color=gray;
#     l1 [label="Source file", shape=box, fillcolor="#eeeeee"];
#     l2 [label="Task", shape=box, fillcolor="#b6f2c2"];
#     l3 [label="Queue", shape=ellipse, fillcolor="#b7d7ff"];
#     l4 [label="ISR", shape=diamond, fillcolor="#ff9999"];
#   }
# }
# EOF

# dot -Tpng "$DOT" -o "$PNG"
# echo "✔ Graf RTOS wygenerowany: $PNG"
#!/bin/bash
set -e

OUT_DIR=graphs/rtos
DOT=$OUT_DIR/rtos.dot
PNG=$OUT_DIR/rtos.png
SRC="Core/Src Core/Inc"

mkdir -p "$OUT_DIR"

# --- Funkcja czyszcząca ---
clean_name() {
  tr -d '\r' | sed 's/(void\*)//g; s/&//g; s/[[:space:]]//g; s/(//g; s/)//g; s/;//g' | grep -v '^$' || true
}

# =================================================
# COLLECT SYMBOLS
# =================================================

FILES=$(find Core/Src -name "*.c" -exec basename {} \; | clean_name | sort -u || true)
TASKS=$(grep -RE "osThreadNew|xTaskCreate" $SRC 2>/dev/null | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name | sort -u || true)
QUEUES=$(grep -RE "xQueueCreate" $SRC 2>/dev/null | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name | grep '^q_' | sort -u || true)
QUEUE_USES=$(grep -RE "xQueueSend|xQueueReceive|xQueueSendFromISR" $SRC 2>/dev/null | grep -oE "q_[a-zA-Z0-9_]+" | sort -u || true)
ISRS=$(grep -R "_IRQHandler" $SRC 2>/dev/null | sed -n 's/.*void \(.*_IRQHandler\).*/\1/p' | clean_name | sort -u || true)

# =================================================
# GRAPH HEADER
# =================================================

cat > "$DOT" <<EOF
digraph RTOS {
  rankdir=LR;
  compound=true;
  graph [
    fontname="Helvetica", 
    bgcolor="white", 
    nodesep=0.15, 
    ranksep=0.6, 
    splines=spline,
    concentrate=true,
    overlap=false
  ];
  node [
    fontname="Helvetica", 
    style="filled,rounded", 
    color="#333333", 
    height=0.25, 
    fontsize=10,
    margin="0.1,0.05"
  ];
  edge [fontname="Helvetica", fontsize=8, arrowsize=0.6];
EOF

# =================================================
# DEFINE ALL NODES
# =================================================

ALL_F=$(grep -rE "xQueue|osThread|_IRQHandler" $SRC 2>/dev/null | cut -d: -f1 | xargs -n1 basename | clean_name | sort -u)
FILES_FINAL=$(echo -e "$FILES\n$ALL_F" | sort -u)

for f in $FILES_FINAL; do
  [ -n "$f" ] && echo "\"$f\" [label=\"$f\", shape=box, fillcolor=\"#eeeeee\"];" >> "$DOT"
done

for t in $TASKS; do
  [ -n "$t" ] && echo "\"$t\" [label=\"Task: $t\", shape=box, fillcolor=\"#b6f2c2\"];" >> "$DOT"
done

ALL_QS=$(echo -e "$QUEUES\n$QUEUE_USES" | sort -u)
for q in $ALL_QS; do
  [ -n "$q" ] && echo "\"$q\" [label=\"Queue: $q\", shape=ellipse, fillcolor=\"#b7d7ff\"];" >> "$DOT"
done

for i in $ISRS; do
  [ -n "$i" ] && echo "\"$i\" [label=\"$i\", shape=diamond, fillcolor=\"#ff9999\"];" >> "$DOT"
done

# =================================================
# EDGES
# =================================================

# --- TASK CREATION ---
grep -RE "osThreadNew|xTaskCreate" $SRC 2>/dev/null | while read -r line; do
  F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
  T=$(echo "$line" | sed -n 's/.*(\([^,]*\).*/\1/p' | clean_name)
  [ -n "$T" ] && echo "\"$F\" -> \"$T\" [color=\"#228b22\", style=dashed, group=\"$F\"];" >> "$DOT"
done

# --- QUEUE OPERATIONS (Z ROZWIĄZANIEM NAKŁADANIA RECV / SENDISR) ---
TEMP_EDGES=$(mktemp)
grep -RE "xQueueSend\(|xQueueReceive|xQueueSendFromISR" $SRC 2>/dev/null | while read -r line; do
  F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
  Q=$(echo "$line" | grep -oE "q_[a-zA-Z0-9_]+" | head -1)
  if [ -n "$Q" ]; then
    if [[ "$line" == *"Receive"* ]]; then echo "$F $Q recv"; 
    elif [[ "$line" == *"FromISR"* ]]; then echo "$F $Q sendISR";
    else echo "$F $Q send"; fi
  fi
done | sort -u > "$TEMP_EDGES"

# Przetwarzamy unikalne pary Plik-Kolejka
cut -d' ' -f1,2 "$TEMP_EDGES" | sort -u | while read -r F Q; do
  types=$(grep "$F $Q" "$TEMP_EDGES" | cut -d' ' -f3 | tr '\n' '/' | sed 's/\/$//')
  
  # Jeśli występuje więcej niż jeden typ operacji (np. sendISR i recv)
  if [[ "$types" == *"/"* ]]; then
    # Wybieramy kolor dominujący (czerwony jeśli jest ISR, inaczej zielony)
    color="#2e8b57"; [[ "$types" == *"ISR"* ]] && color="#b22222"
    # Używamy dir=both, jeśli w zestawie jest 'recv' i dowolny 'send'
    dir="forward"; [[ "$types" == *"recv"* && ("$types" == *"send"*) ]] && dir="both"
    
    echo "\"$F\" -> \"$Q\" [label=\"$types\", color=\"$color\", dir=\"$dir\", arrowtail=dot, tailcolor=\"#ff8c00\"];" >> "$DOT"
  else
    # Pojedyncze operacje (klasyczne)
    case "$types" in
      "recv")    echo "\"$Q\" -> \"$F\" [label=\"recv\", color=\"#ff8c00\"];" >> "$DOT" ;;
      "sendISR") echo "\"$F\" -> \"$Q\" [label=\"sendISR\", color=\"#b22222\", penwidth=1.5];" >> "$DOT" ;;
      "send")    echo "\"$F\" -> \"$Q\" [label=\"send\", color=\"#2e8b57\"];" >> "$DOT" ;;
    esac
  fi
done
rm "$TEMP_EDGES"

# --- ISR → FILE ---
grep -R "_IRQHandler" $SRC 2>/dev/null | while read -r line; do
  I=$(echo "$line" | sed -n 's/.*void \(.*_IRQHandler\).*/\1/p' | clean_name)
  F=$(basename "$(echo "$line" | cut -d: -f1)" | clean_name)
  [ -n "$I" ] && echo "\"$I\" -> \"$F\" [color=\"#b22222\"];" >> "$DOT"
done

# =================================================
# LEGEND & CLOSE
# =================================================

cat >> "$DOT" <<EOF
  subgraph cluster_legend {
    label="Legend"; style=dashed; color=gray;
    l1 [label="Source file", shape=box, fillcolor="#eeeeee"];
    l2 [label="Task", shape=box, fillcolor="#b6f2c2"];
    l3 [label="Queue", shape=ellipse, fillcolor="#b7d7ff"];
    l4 [label="ISR", shape=diamond, fillcolor="#ff9999"];
  }
}
EOF

dot -Tpng "$DOT" -o "$PNG"
echo "✔ Graf RTOS wygenerowany: $PNG"
