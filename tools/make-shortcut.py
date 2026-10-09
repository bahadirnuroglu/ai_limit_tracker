#!/usr/bin/env python3
"""'AI Limitlerim' kestirmesini üretir ve imzalar:  python3 tools/make-shortcut.py <çıktı-klasörü>

Kestirme: ailimittracker://x-callback-url/limits adresini açar (uygulama verileri tazeleyip özeti
x-success ile "result" parametresinde geri yollar), result değerini alır ve gösterir / Siri'de okur.
App Intents Xcode'un metadata aracını gerektirdiği için (bu makinede yok) x-callback yolu kullanılır.
"""
import plistlib, subprocess, sys, uuid, os

out_dir = sys.argv[1]
u1, u2 = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
workflow = {
    "WFWorkflowClientVersion": "2607.0.3",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4292093695, "WFWorkflowIconGlyphNumber": 61440},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowTypes": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowHasShortcutInputVariables": False,
    "WFWorkflowActions": [
        {"WFWorkflowActionIdentifier": "is.workflow.actions.openxcallbackurl",
         "WFWorkflowActionParameters": {"WFXCallbackURL": "ailimittracker://x-callback-url/limits", "UUID": u1}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey",
         "WFWorkflowActionParameters": {
             "WFGetDictionaryValueType": "Value", "WFDictionaryKey": "result", "UUID": u2,
             "WFInput": {"Value": {"OutputUUID": u1, "Type": "ActionOutput", "OutputName": "X-Callback Result"},
                         "WFSerializationType": "WFTextTokenAttachment"}}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.showresult",
         "WFWorkflowActionParameters": {
             "Text": {"Value": {"string": "￼", "attachmentsByRange": {
                 "{0, 1}": {"OutputUUID": u2, "Type": "ActionOutput", "OutputName": "Dictionary Value"}}},
                      "WFSerializationType": "WFTextTokenString"}}},
    ],
}
unsigned = os.path.join(out_dir, "unsigned.shortcut")
signed = os.path.join(out_dir, "AI Limitlerim.shortcut")
with open(unsigned, "wb") as f:
    plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
r = subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", signed],
                   capture_output=True, text=True)
os.remove(unsigned)
if r.returncode != 0 or not os.path.exists(signed):
    sys.exit("kestirme imzalanamadı: " + (r.stderr or r.stdout).strip())
print("Hazır:", signed)
