from flask import Flask, jsonify
import requests
import pandas as pd
from geopy.geocoders import Nominatim
import spacy
import time
import os

app = Flask(__name__)

# Initialize API key, geolocator, and NLP model
api_key = 'c1a6297afc9a441c9a9ee4096d939482'
geolocator = Nominatim(user_agent="geoapi")
nlp = spacy.load("en_core_web_sm")

# Known places within Maharashtra
known_places = [
    "Govandi", "Bandra", "Dadar", "Borivali", "Chembur", "Badlapur", "Kurla", "Navi Mumbai", 
    "Vashi", "Airoli", "Panvel", "Churchgate", "Mumbai Central", "Marine Lines", "Charni Road", 
    "Grant Road", "Lower Parel", "Mahalaxmi", "Elphinstone Road", "Matunga Road", "Mahim", 
    "Khar Road", "Santacruz", "Vile Parle", "Andheri", "Jogeshwari", "Goregaon", "Malad", 
    "Kandivali", "Dahisar", "Mira Road", "Bhayandar", "Naigaon", "Vasai Road", "Nalasopara", 
    "Virar", "Vikhroli", "Ghatkopar", "Kanjurmarg", "Bhandup", "Mulund", "Thane", "Kalwa", 
    "Mumbra", "Diva", "Kopar", "Dombivli", "Thakurli", "Kalyan", "Shahad", "Ambivli", 
    "Titwala", "Asangaon", "Atgaon", "Khardi", "Kasara", "Vasind", "Bhivpuri", "Neral", 
    "Shelu", "Vangani", "Karjat", "Palasdhari", "Chowk", "Kelavli", "Dolavli", "Lowjee", 
    "Khopoli", "Belapur", "Seawoods", "Kharghar", "Taloja", "Khandeshwar", "Kalamboli", 
    "Ghansoli", "Rabale", "Turbhe", "Sanpada", "Mankhurd",
    "Pune", "Shivajinagar", "Hinjewadi", "Kothrud", "Kharadi", "Wakad", "Hadapsar", "Katraj", 
    "Viman Nagar", "Pimpri", "Chinchwad", "Baner", "Aundh", "Deccan", "Bhosari", "Nigdi", 
    "Talegaon", "Akurdi", "Kasarwadi", "Khadki", "Swar Gate", "Camp", "Pune Station", 
    "Bibwewadi", "Warje", "Magarpatta", "Pashan", "Balewadi",
    "Nagpur", "Sadar", "Sitabuldi", "Jaripatka", "Mankapur", "Lakadganj", "Kamptee", 
    "Koradi", "Hingna", "Wardhaman Nagar", "Gittikhadan", "Katol Road", "Manewada",
    "Nashik", "Dwarka", "Deolali", "CIDCO", "Satpur", "Panchavati", "Sinnar", "Malegaon", 
    "Bhagur", "Ozar", "Trimbak", "Igatpuri",
    "Aurangabad", "Chikalthana", "MIDC", "Waluj", "CIDCO", "Paithan", "Vaijapur", "Kannad",
    "Kolhapur", "Ichalkaranji", "Gadhinglaj", "Karvir", "Shahapur", "Laxmipuri", 
    "Shiroli", "Hatkanangale",
    "Solapur", "Sangli", "Satara", "Ahmednagar", "Jalgaon", "Dhule", "Ratnagiri", 
    "Sindhudurg", "Latur", "Beed", "Osmanabad", "Nanded", "Yavatmal", "Amravati", "Akola", 
    "Chandrapur", "Gondia", "Bhandara", "Parbhani", "Hingoli", "Jalna"
]

# Crime keywords mapping
crime_keywords = {
    "rape": ["rape", "sexual assault", "sexually assaulted", "molestation"],
    "molestation": ["molestation", "groping", "inappropriate touching"],
    "kidnapping": ["kidnap", "abduction", "missing"],
    "murder": ["murder", "homicide", "killing", "shot", "stabbed", "attack"],
    "smuggling": ["smuggle", "contraband", "illegal trafficking", "seize"],
    "theft": ["theft", "robbery", "burglary", "stealing", "stolen"],
    "domestic violence": ["domestic violence", "wife beating", "spousal abuse", "abuse"]
}

@app.route('/')
def home():
    return "Flask is running!"

# Function to get coordinates from a location
def get_location_coordinates(location):
    try:
        loc = geolocator.geocode(location + ", Maharashtra")
        if loc:
            return loc.latitude, loc.longitude
        else:
            return None, None  # Return None if not found
    except Exception as e:
        print(f"Geocoding error: {e}")
        return None, None

@app.route('/fetch_crime_data', methods=['GET'])
def fetch_crime_data():
    try:
        df = fetch_crime_articles()  # Fetch and process the articles
        save_to_csv(df)  # Save the data into a CSV file
        print("Fetched data:", df.to_dict(orient='records'))  # Debugging line
        return jsonify({"message": "Data fetched and processed successfully", "data": df.to_dict(orient='records')}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def fetch_crime_articles():
    url = f'https://newsapi.org/v2/everything?q="crime" AND "Maharashtra"&apiKey={api_key}'
    
    response = requests.get(url)
    articles = response.json().get('articles', [])

    data = []
    seen_articles = set()

    for article in articles:
        title = article.get('title')
        content = article.get('content', "")
        date = article.get('publishedAt')

        # Skip if title is None or already seen
        if not title or title in seen_articles:
            continue
        
        location = extract_location(content)
        if not location:
            continue
        
        crime_type = extract_crime_type(content)
        latitude, longitude = get_location_coordinates(location)
        
        if latitude is not None and longitude is not None:
            data.append({
                'title': title,
                'location': location,
                'latitude': latitude,
                'longitude': longitude,
                'crime_type': crime_type,
                'content': content
            })
            seen_articles.add(title)
        
        time.sleep(1)  # Avoid overwhelming geolocation service
    
    return pd.DataFrame(data)

def extract_location(content):
    if not isinstance(content, str):
        return None

    for place in known_places:
        if place.lower() in content.lower():
            return place
    
    doc = nlp(content)
    for entity in doc.ents:
        if entity.label_ in ["GPE", "LOC"]:
            if any(known_place.lower() in entity.text.lower() for known_place in known_places):
                return entity.text
    return None

def extract_crime_type(content):
    if not isinstance(content, str):
        print("Content is not a string.")
        return "unknown"

    content_lower = content.lower()
    for crime, keywords in crime_keywords.items():
        print(f"Checking for {crime} in content: {content_lower}")
        if any(keyword in content_lower for keyword in keywords):
            print(f"Matched {crime} with keywords: {keywords}")
            return crime
    
    print("No matches found, returning 'unknown'.")
    return "unknown"

def save_to_csv(new_df, file_path='crime_data_maharashtra.csv'):
    if os.path.exists(file_path):
        existing_df = pd.read_csv(file_path)
        updated_df = pd.concat([existing_df, new_df]).drop_duplicates().reset_index(drop=True)
    else:
        updated_df = new_df
    
    updated_df.to_csv(file_path, index=False)
    print(f"Data saved to {file_path}")

if __name__ == '__main__':
    app.run(host='192.168.0.107', port=5000, debug=True)  # Updated line
