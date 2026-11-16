"""Fetches real product pictures from Open Food Facts for the demo screens.

Run before tool/screens/screens_test.dart:  python3 tool/screens/fetch_pictures.py
Writes tool/screens/pictures/*.jpg (not committed) and tool/screens/pictures.json
(name -> picture URL). Pictures: Open Food Facts, CC BY-SA 3.0.
"""
import json, os, urllib.parse, urllib.request

UA = "PantryApp/0.5 (chris@combinationsoupstudio.com.au)"
HERE = os.path.dirname(os.path.abspath(__file__))
WANT = {
    "Washed potatoes": "washed potatoes",
    "Soy sauce": "kikkoman soy sauce",
    "Olive oil": "extra virgin olive oil",
    "Rolled oats": "rolled oats",
    "Pasta": "spaghetti",
    "Tins: tomatoes": "diced tomatoes",
    "UHT milk": "long life milk",
    "Eggs": "free range eggs",
    "Frozen peas": "frozen peas",
    "Butter": "salted butter block",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()

def file_name(url):
    parts = [p for p in urllib.parse.urlparse(url).path.split("/") if p]
    if "products" in parts:
        parts = parts[parts.index("products") + 1:]
    return "_".join(parts)

out = {}
os.makedirs(os.path.join(HERE, "pictures"), exist_ok=True)
for name, query in WANT.items():
    q = urllib.parse.quote(f'{query} countries_tags:"en:australia"')
    data = json.loads(get(f"https://search.openfoodfacts.org/search?q={q}&page_size=10&fields=code,product_name,image_front_small_url"))
    hit = next((h for h in data.get("hits", []) if h.get("image_front_small_url", "").startswith("https://")), None)
    if not hit:
        print("no picture:", name); continue
    url = hit["image_front_small_url"]
    path = os.path.join(HERE, "pictures", file_name(url))
    if not os.path.exists(path):
        open(path, "wb").write(get(url))
    out[name] = url
    print(f"{name}: {hit.get('product_name')} -> {os.path.getsize(path)} bytes")
# A name search, as "Find picture" shows it.
q = urllib.parse.quote('washed potatoes countries_tags:"en:australia"')
data = json.loads(get(f"https://search.openfoodfacts.org/search?q={q}&page_size=24&fields=code,product_name,brands,quantity,image_front_small_url"))
hits = [h for h in data.get("hits", []) if h.get("image_front_small_url", "").startswith("https://")][:9]
for h in hits:
    path = os.path.join(HERE, "pictures", file_name(h["image_front_small_url"]))
    if not os.path.exists(path):
        open(path, "wb").write(get(h["image_front_small_url"]))
out["_search"] = hits
print("search hits:", [(h.get("product_name"), h.get("quantity")) for h in hits])
json.dump(out, open(os.path.join(HERE, "pictures.json"), "w"), indent=2)
