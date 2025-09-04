const axios = require('axios');
const http = require('http');
const https = require('https');
const logger = require('../utils/logger');
const cacheService = require('./cacheService');
const cacheService = require('./cacheService');

class ExternalApiService {
  constructor() {
    this.googleMapsApiKey = process.env.GOOGLE_MAPS_API_KEY;
    this.googlePlacesApiKey = process.env.GOOGLE_PLACES_API_KEY;
    this.openWeatherApiKey = process.env.OPENWEATHER_API_KEY;
    this.eventbriteApiKey = process.env.EVENTBRITE_API_KEY;
    this.yelpApiKey = process.env.YELP_API_KEY;
  }

  getHttpClient() {
    if (!this.httpClient) {
      const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 100 });
      const httpsAgent = new https.Agent({ keepAlive: true, maxSockets: 100 });
      this.httpClient = axios.create({
        timeout: 10000,
        httpAgent,
        httpsAgent,
        validateStatus: (s) => s >= 200 && s < 300
      });
    }
    return this.httpClient;
  }

  async safeGet(url, options = {}, retries = 2) {
    const client = this.getHttpClient();
    let attempt = 0;
    while (true) {
      try {
        return await client.get(url, options);
      } catch (err) {
        attempt++;
        if (attempt > retries) throw err;
      }
    }
  }

  // Google Maps API methods
  async getNearbyPlaces(location, radius = 5000, type = 'establishment', keyword = null) {
    try {
      const cacheKey = `places:${location.lat}:${location.lng}:${radius}:${type}:${keyword || 'all'}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
      const params = {
        location: `${location.lat},${location.lng}`,
        radius: radius,
        type: type,
        key: this.googleMapsApiKey
      };

      if (keyword) {
        params.keyword = keyword;
      }

      const response = await axios.get(url, { params });
      
      if (response.data.status !== 'OK') {
        throw new Error(`Google Places API error: ${response.data.status}`);
      }

      const places = response.data.results.map(place => ({
        placeId: place.place_id,
        name: place.name,
        type: place.types[0],
        rating: place.rating,
        priceLevel: place.price_level,
        location: {
          lat: place.geometry.location.lat,
          lng: place.geometry.location.lng
        },
        vicinity: place.vicinity,
        photos: place.photos?.map(photo => 
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photo_reference}&key=${this.googleMapsApiKey}`
        ) || [],
        isOpen: place.opening_hours?.open_now
      }));

      await cacheService.set(cacheKey, places, 1800); // Cache for 30 minutes
      return places;

    } catch (error) {
      logger.error('Google Places API error:', error);
      throw new Error(`Failed to fetch nearby places: ${error.message}`);
    }
  }

  async getPlaceDetails(placeId) {
    try {
      const cacheKey = `place_details:${placeId}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://maps.googleapis.com/maps/api/place/details/json';
      const params = {
        place_id: placeId,
        fields: 'name,formatted_address,geometry,rating,price_level,photos,formatted_phone_number,website,opening_hours,reviews',
        key: this.googleMapsApiKey
      };

      const response = await axios.get(url, { params });
      
      if (response.data.status !== 'OK') {
        throw new Error(`Google Places Details API error: ${response.data.status}`);
      }

      const place = response.data.result;
      const details = {
        placeId: place.place_id,
        name: place.name,
        address: place.formatted_address,
        location: {
          lat: place.geometry.location.lat,
          lng: place.geometry.location.lng
        },
        rating: place.rating,
        priceLevel: place.price_level,
        phone: place.formatted_phone_number,
        website: place.website,
        photos: place.photos?.map(photo => 
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photo_reference}&key=${this.googleMapsApiKey}`
        ) || [],
        openingHours: place.opening_hours?.weekday_text || [],
        reviews: place.reviews?.slice(0, 5).map(review => ({
          author: review.author_name,
          rating: review.rating,
          text: review.text,
          time: review.time
        })) || []
      };

      await cacheService.set(cacheKey, details, 3600); // Cache for 1 hour
      return details;

    } catch (error) {
      logger.error('Google Places Details API error:', error);
      throw new Error(`Failed to fetch place details: ${error.message}`);
    }
  }

  async getDirections(origin, destination, mode = 'walking') {
    try {
      const cacheKey = `directions:${origin.lat}:${origin.lng}:${destination.lat}:${destination.lng}:${mode}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://maps.googleapis.com/maps/api/directions/json';
      const params = {
        origin: `${origin.lat},${origin.lng}`,
        destination: `${destination.lat},${destination.lng}`,
        mode: mode,
        key: this.googleMapsApiKey
      };

      const response = await axios.get(url, { params });
      
      if (response.data.status !== 'OK') {
        throw new Error(`Google Directions API error: ${response.data.status}`);
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];
      
      const directions = {
        distance: {
          text: leg.distance.text,
          value: leg.distance.value // in meters
        },
        duration: {
          text: leg.duration.text,
          value: leg.duration.value // in seconds
        },
        steps: leg.steps.map(step => ({
          instruction: step.html_instructions,
          distance: step.distance,
          duration: step.duration,
          startLocation: {
            lat: step.start_location.lat,
            lng: step.start_location.lng
          },
          endLocation: {
            lat: step.end_location.lat,
            lng: step.end_location.lng
          }
        })),
        polyline: route.overview_polyline.points
      };

      await cacheService.set(cacheKey, directions, 3600); // Cache for 1 hour
      return directions;

    } catch (error) {
      logger.error('Google Directions API error:', error);
      throw new Error(`Failed to get directions: ${error.message}`);
    }
  }

  // OpenWeather API methods
  async getCurrentWeather(location) {
    try {
      const cacheKey = `weather_current:${location.lat}:${location.lng}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://api.openweathermap.org/data/2.5/weather';
      const params = {
        lat: location.lat,
        lon: location.lng,
        appid: this.openWeatherApiKey,
        units: 'imperial'
      };

      const response = await axios.get(url, { params });
      
      const weather = {
        condition: response.data.weather[0].main,
        description: response.data.weather[0].description,
        temperature: Math.round(response.data.main.temp),
        feelsLike: Math.round(response.data.main.feels_like),
        humidity: response.data.main.humidity,
        windSpeed: response.data.wind.speed,
        windDirection: response.data.wind.deg,
        visibility: response.data.visibility,
        uvIndex: response.data.uvi,
        timestamp: new Date(response.data.dt * 1000)
      };

      await cacheService.set(cacheKey, weather, 900); // Cache for 15 minutes
      return weather;

    } catch (error) {
      logger.error('OpenWeather API error:', error);
      throw new Error(`Failed to fetch weather: ${error.message}`);
    }
  }

  async getWeatherForecast(location, days = 5) {
    try {
      const cacheKey = `weather_forecast:${location.lat}:${location.lng}:${days}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://api.openweathermap.org/data/2.5/forecast';
      const params = {
        lat: location.lat,
        lon: location.lng,
        appid: this.openWeatherApiKey,
        units: 'imperial'
      };

      const response = await axios.get(url, { params });
      
      const forecast = response.data.list.slice(0, days * 8).map(item => ({
        time: new Date(item.dt * 1000),
        condition: item.weather[0].main,
        description: item.weather[0].description,
        temperature: Math.round(item.main.temp),
        feelsLike: Math.round(item.main.feels_like),
        humidity: item.main.humidity,
        windSpeed: item.wind.speed,
        precipitation: item.rain?.['3h'] || item.snow?.['3h'] || 0
      }));

      await cacheService.set(cacheKey, forecast, 1800); // Cache for 30 minutes
      return forecast;

    } catch (error) {
      logger.error('OpenWeather Forecast API error:', error);
      throw new Error(`Failed to fetch weather forecast: ${error.message}`);
    }
  }

  // Eventbrite API methods
  async getNearbyEvents(location, radius = 5000, category = null) {
    try {
      const cacheKey = `eventbrite:${location.lat}:${location.lng}:${radius}:${category || 'all'}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://www.eventbriteapi.com/v3/events/search/';
      const params = {
        'location.latitude': location.lat,
        'location.longitude': location.lng,
        'location.within': `${radius}m`,
        'expand': 'venue,organizer',
        'status': 'live',
        'time_filter': 'current_future'
      };

      if (category) {
        params.categories = category;
      }

      const response = await axios.get(url, {
        params,
        headers: {
          'Authorization': `Bearer ${this.eventbriteApiKey}`
        }
      });

      const events = response.data.events.map(event => ({
        eventId: event.id,
        name: event.name.text,
        description: event.description.text,
        startTime: new Date(event.start.utc),
        endTime: new Date(event.end.utc),
        location: {
          lat: parseFloat(event.venue.latitude),
          lng: parseFloat(event.venue.longitude),
          address: event.venue.address.localized_address_display
        },
        venue: {
          name: event.venue.name,
          capacity: event.capacity,
          type: event.venue.category_id
        },
        category: event.category_id,
        price: {
          isFree: event.is_free,
          amount: event.is_free ? 0 : parseFloat(event.ticket_availability.minimum_ticket_price.major_value)
        },
        url: event.url,
        status: event.status
      }));

      await cacheService.set(cacheKey, events, 1800); // Cache for 30 minutes
      return events;

    } catch (error) {
      logger.error('Eventbrite API error:', error);
      throw new Error(`Failed to fetch events: ${error.message}`);
    }
  }

  // Yelp API methods
  async getNearbyBusinesses(location, radius = 5000, category = null, limit = 20) {
    try {
      const cacheKey = `yelp:${location.lat}:${location.lng}:${radius}:${category || 'all'}:${limit}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://api.yelp.com/v3/businesses/search';
      const params = {
        latitude: location.lat,
        longitude: location.lng,
        radius: radius,
        limit: limit,
        sort_by: 'rating'
      };

      if (category) {
        params.categories = category;
      }

      const response = await axios.get(url, {
        params,
        headers: {
          'Authorization': `Bearer ${this.yelpApiKey}`
        }
      });

      const businesses = response.data.businesses.map(business => ({
        businessId: business.id,
        name: business.name,
        type: business.categories[0]?.alias || 'business',
        rating: business.rating,
        priceLevel: business.price?.length || 0,
        location: {
          lat: business.coordinates.latitude,
          lng: business.coordinates.longitude,
          address: business.location.display_address.join(', ')
        },
        phone: business.display_phone,
        website: business.url,
        photos: business.photos || [],
        isOpen: business.hours?.[0]?.is_open_now,
        reviews: business.review_count
      }));

      await cacheService.set(cacheKey, businesses, 1800); // Cache for 30 minutes
      return businesses;

    } catch (error) {
      logger.error('Yelp API error:', error);
      throw new Error(`Failed to fetch businesses: ${error.message}`);
    }
  }

  // Geocoding methods
  async geocodeAddress(address) {
    try {
      const cacheKey = `geocode:${address}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://maps.googleapis.com/maps/api/geocode/json';
      const params = {
        address: address,
        key: this.googleMapsApiKey
      };

      const response = await axios.get(url, { params });
      
      if (response.data.status !== 'OK') {
        throw new Error(`Google Geocoding API error: ${response.data.status}`);
      }

      const result = response.data.results[0];
      const location = {
        lat: result.geometry.location.lat,
        lng: result.geometry.location.lng,
        address: result.formatted_address,
        placeId: result.place_id,
        components: result.address_components
      };

      await cacheService.set(cacheKey, location, 86400); // Cache for 24 hours
      return location;

    } catch (error) {
      logger.error('Google Geocoding API error:', error);
      throw new Error(`Failed to geocode address: ${error.message}`);
    }
  }

  async reverseGeocode(location) {
    try {
      const cacheKey = `reverse_geocode:${location.lat}:${location.lng}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const url = 'https://maps.googleapis.com/maps/api/geocode/json';
      const params = {
        latlng: `${location.lat},${location.lng}`,
        key: this.googleMapsApiKey
      };

      const response = await axios.get(url, { params });
      
      if (response.data.status !== 'OK') {
        throw new Error(`Google Reverse Geocoding API error: ${response.data.status}`);
      }

      const result = response.data.results[0];
      const address = {
        lat: location.lat,
        lng: location.lng,
        address: result.formatted_address,
        placeId: result.place_id,
        components: result.address_components
      };

      await cacheService.set(cacheKey, address, 86400); // Cache for 24 hours
      return address;

    } catch (error) {
      logger.error('Google Reverse Geocoding API error:', error);
      throw new Error(`Failed to reverse geocode: ${error.message}`);
    }
  }

  // Combined data fetching for adventure generation
  async getAdventureData(location, radius = 5000, interests = []) {
    try {
      const [weather, places, events, businesses] = await Promise.allSettled([
        this.getCurrentWeather(location),
        this.getNearbyPlaces(location, radius, 'establishment'),
        this.getNearbyEvents(location, radius),
        this.getNearbyBusinesses(location, radius, interests.join(','))
      ]);

      return {
        weather: weather.status === 'fulfilled' ? weather.value : null,
        places: places.status === 'fulfilled' ? places.value : [],
        events: events.status === 'fulfilled' ? events.value : [],
        businesses: businesses.status === 'fulfilled' ? businesses.value : [],
        errors: [
          weather.status === 'rejected' ? weather.reason.message : null,
          places.status === 'rejected' ? places.reason.message : null,
          events.status === 'rejected' ? events.reason.message : null,
          businesses.status === 'rejected' ? businesses.reason.message : null
        ].filter(Boolean)
      };

    } catch (error) {
      logger.error('Failed to fetch adventure data:', error);
      throw new Error(`Failed to fetch adventure data: ${error.message}`);
    }
  }
}

module.exports = new ExternalApiService();
