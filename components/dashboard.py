import os
import json
import logging
import hashlib
from threading import Thread, Event
# HTTP server/interface modules         
from flask import Flask, abort, jsonify, request
from flask_cors import CORS
import webview

def log_encounter(pokemon: dict):
    # Statistics
    global record_ivSum, record_shinyValue, record_encounters, encounters
    iv_sum = pokemon["hpIV"] + pokemon["attackIV"] + pokemon["defenseIV"] + pokemon["spAttackIV"] + pokemon["spDefenseIV"] + pokemon["speedIV"]

    totals["highest_iv_sum"]        = iv_sum if totals["highest_iv_sum"] == None else max(totals["highest_iv_sum"], iv_sum)
    totals["lowest_sv"]   = pokemon["shinyValue"] if totals["lowest_sv"] == None else min(totals["lowest_sv"], pokemon["shinyValue"])
    totals["encounters"]   += 1

    print("--------------")
    print(f"Seen Pokemon #{totals['encounters']}: a {pokemon['nature']} {pokemon['name']}!")
    print(f"HP: {pokemon['hpIV']}, ATK: {pokemon['attackIV']}, DEF: {pokemon['defenseIV']}, SP.ATK: {pokemon['spAttackIV']}, SP.DEF: {pokemon['spDefenseIV']}, SPD: {pokemon['speedIV']}")
    print(f"Shiny Value: {pokemon['shinyValue']}, Shiny?: {str(pokemon['shiny'])}")
    print("")
    print(f"Highest IV sum: {totals['highest_iv_sum']}")
    print(f"Lowest shiny value: {totals['lowest_sv']}")
    print("--------------")

    encounters["encounters"].append(pokemon)
    
    write_file("stats/totals.json", json.dumps(totals, indent=4, sort_keys=True)) # Save stats file
    write_file("stats/encounters.json", json.dumps(encounters, indent=4, sort_keys=True)) # Save encounter log file

@staticmethod
def read_file(file: str):
    if os.path.exists(file):
        with open(file, mode="r", encoding="utf-8") as open_file:
            return open_file.read()
    else:
        return False

@staticmethod
def write_file(file: str, value: str):
    dirname = os.path.dirname(file)
    if not os.path.exists(dirname):
        os.makedirs(dirname)

    with open(file, mode="w", encoding="utf-8") as save_file:
        save_file.write(value)
        return True

# Run HTTP server to make data available via HTTP GET
def httpServer():
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)

    server = Flask(__name__)
    CORS(server)

    @server.route('/totals', methods=['GET'])
    def req_stats():
        if totals:
            response = jsonify(totals)
            return response
        else: abort(503)
    @server.route('/encounters', methods=['GET'])
    def req_encounters():
        if encounters:
            # Add a hash so dashboard.js knows whether to update its list
            enc_hashed = encounters.copy()
            enc_hashed["hash"] = hashlib.md5(json.dumps(encounters, sort_keys=True).encode()).hexdigest()
            response = jsonify(enc_hashed)
            
            return response
        else: abort(503)
    server.run(debug=False, threaded=True, host="127.0.0.1", port=6969)

def dashboard_init():
    def on_window_close():
        print("Dashboard closed on user input")
        os._exit(1)

    window = webview.create_window("PokeBot Gen V", url="../ui/dashboard.html", width=1280, height=720, resizable=True, hidden=False, frameless=False, easy_drag=True, fullscreen=False, text_select=True, zoomable=True)
    window.events.closed += on_window_close

    webview.start()

os.makedirs("stats", exist_ok=True) # Sets up stats files if they don't exist

file = read_file("stats/totals.json")
totals = json.loads(file) if file else {
    "highest_iv_sum": 0, 
    "lowest_sv": 65535, 
    "encounters": 0, 
}

file = read_file("stats/encounters.json")
encounters = json.loads(file) if file else { "encounters": [] }

http_server = Thread(target=httpServer)
http_server.start()