import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

from external import service_weather


class ExternalGeocodeTest(unittest.IsolatedAsyncioTestCase):
    def _valid_cache(self) -> dict:
        return {
            "id": 301,
            "status": "success",
            "lat": 25.033,
            "lng": 121.5654,
            "expires_at": datetime.now(timezone.utc) + timedelta(days=30),
        }

    async def test_repeated_address_calls_provider_only_once(self):
        provider_response = MagicMock(status_code=200)
        provider_response.json.return_value = [
            {"lat": 25.033, "lon": 121.5654}
        ]
        client = AsyncMock()
        client.get.return_value = provider_response
        client_context = MagicMock()
        client_context.__aenter__ = AsyncMock(return_value=client)
        client_context.__aexit__ = AsyncMock(return_value=None)

        with (
            patch.object(
                service_weather,
                "get_geocode_cache",
                side_effect=[None, self._valid_cache()],
            ) as read_cache,
            patch.object(
                service_weather,
                "claim_geocode_refresh",
                return_value=301,
            ) as claim_refresh,
            patch.object(service_weather, "save_geocode_result") as save_result,
            patch.object(service_weather, "_require_open_weather_api_key", return_value="test-key"),
            patch.object(service_weather._geocode_rate_limiter, "check") as check_limit,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
                return_value=client_context,
            ),
        ):
            first = await service_weather.geocode(
                service_weather.GeocodeRequest(query="Taipei 101"),
                {"id": "geocode-test-user"},
            )
            second = await service_weather.geocode(
                service_weather.GeocodeRequest(query="  Taipei   101  "),
                {"id": "geocode-test-user"},
            )

        self.assertEqual(first, second)
        self.assertEqual(read_cache.call_count, 2)
        claim_refresh.assert_called_once()
        check_limit.assert_called_once_with("geocode-test-user")
        client.get.assert_awaited_once()
        save_result.assert_called_once()
        self.assertEqual(save_result.call_args.kwargs["ttl_days"], 180)

        query_hash = claim_refresh.call_args.args[0]
        self.assertEqual(len(query_hash), 64)
        self.assertNotIn("Taipei", query_hash)

    async def test_valid_cache_does_not_claim_or_call_provider(self):
        with (
            patch.object(
                service_weather,
                "get_geocode_cache",
                return_value=self._valid_cache(),
            ),
            patch.object(service_weather, "claim_geocode_refresh") as claim_refresh,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
            ) as http_client,
        ):
            response = await service_weather.geocode(
                service_weather.GeocodeRequest(query="Taipei 101"),
                {"id": "cached-test-user"},
            )

        self.assertEqual(response.lat, 25.033)
        self.assertEqual(response.lng, 121.5654)
        claim_refresh.assert_not_called()
        http_client.assert_not_called()

    async def test_map_geocode_uses_saved_coordinates_without_provider(self):
        with (
            patch.object(
                service_weather,
                "get_event_map_location",
                return_value={
                    "country": "TW",
                    "city": "Taipei",
                    "location": "Taipei 101",
                    "map_lat": 25.033,
                    "map_lng": 121.5654,
                },
            ),
            patch.object(service_weather, "_geocode_query") as provider,
            patch.object(
                service_weather,
                "save_event_map_coordinates",
            ) as save_coordinates,
        ):
            response = await service_weather.map_geocode(
                service_weather.EventMapGeocodeRequest(
                    table_name="recommended_events",
                    event_id="event-1",
                ),
                {"id": "user-1", "email": "user@example.com"},
            )

        self.assertEqual(response.lat, 25.033)
        self.assertEqual(response.lng, 121.5654)
        provider.assert_not_called()
        save_coordinates.assert_not_called()

    async def test_map_geocode_queries_full_address_and_saves_coordinates(self):
        event_without_coordinates = {
            "country": "TW",
            "city": "Taipei",
            "location": "Taipei 101",
            "map_lat": None,
            "map_lng": None,
        }
        with (
            patch.object(
                service_weather,
                "get_event_map_location",
                return_value=event_without_coordinates,
            ),
            patch.object(
                service_weather,
                "_geocode_query",
                return_value=service_weather.GeocodeResponse(
                    lat=25.033,
                    lng=121.5654,
                ),
            ) as provider,
            patch.object(
                service_weather,
                "save_event_map_coordinates",
                return_value={"lat": 25.033, "lng": 121.5654},
            ) as save_coordinates,
        ):
            response = await service_weather.map_geocode(
                service_weather.EventMapGeocodeRequest(
                    table_name="recommended_events",
                    event_id="event-1",
                ),
                {"id": "user-1", "email": "user@example.com"},
            )

        provider.assert_awaited_once_with(
            "Taipei 101, Taipei, TW",
            "user-1",
        )
        save_coordinates.assert_called_once()
        self.assertEqual(response.lat, 25.033)
        self.assertEqual(response.lng, 121.5654)


if __name__ == "__main__":
    unittest.main()
