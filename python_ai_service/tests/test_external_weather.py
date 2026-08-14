import asyncio
import unittest
from datetime import timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException
from pydantic import ValidationError

from external import service_weather


class ExternalWeatherTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        service_weather._weather_cache.clear()
        service_weather._weather_in_flight.clear()

    def _provider_context(self, response: MagicMock) -> MagicMock:
        client = AsyncMock()
        client.get.return_value = response
        context = MagicMock()
        context.__aenter__ = AsyncMock(return_value=client)
        context.__aexit__ = AsyncMock(return_value=None)
        return context

    async def test_returns_sanitized_forecast(self):
        provider_response = MagicMock(status_code=200)
        provider_response.json.return_value = {
            "city": {"timezone": 28800},
            "list": [
                {
                    "dt": 1786665600,
                    "weather": [
                        {
                            "main": "Clear",
                            "description": "clear sky",
                            "icon": "01d",
                        }
                    ],
                    "main": {
                        "temp": 28.5,
                        "feels_like": 30.0,
                        "temp_min": 27.0,
                        "temp_max": 29.0,
                        "pressure": 1008,
                        "sea_level": 1008,
                        "grnd_level": 1005,
                    },
                }
            ]
        }
        provider_context = self._provider_context(provider_response)

        with (
            patch.object(
                service_weather,
                "_require_open_weather_api_key",
                return_value="test-key",
            ),
            patch.object(
                service_weather,
                "get_weather_forecast_cache",
                return_value=None,
            ),
            patch.object(
                service_weather,
                "save_weather_forecast_cache",
            ) as save_persistent_cache,
            patch.object(
                service_weather._weather_rate_limiter,
                "check",
            ) as check_limit,
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
            ) as check_global_limit,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
                return_value=provider_context,
            ),
        ):
            result = await service_weather.weather_forecast(
                service_weather.WeatherRequest(lat=25.033, lng=121.5654),
                {"id": "weather-test-user"},
            )

        check_limit.assert_called_once_with("weather-test-user")
        check_global_limit.assert_called_once_with("open_weather_forecast")
        self.assertEqual(len(result.items), 1)
        self.assertEqual(result.items[0].main, "Clear")
        self.assertEqual(result.items[0].temp, 28.5)
        save_persistent_cache.assert_called_once()
        expires_at = save_persistent_cache.call_args.kwargs["expires_at"]
        location_expiry = expires_at.astimezone(
            timezone(timedelta(hours=8))
        )
        self.assertEqual(location_expiry.hour, 0)
        self.assertEqual(location_expiry.minute, 0)

        with (
            patch.object(
                service_weather._weather_rate_limiter,
                "check",
            ) as cached_user_limit,
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
            ) as cached_global_limit,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
            ) as cached_http_client,
        ):
            cached = await service_weather.weather_forecast(
                service_weather.WeatherRequest(
                    lat=25.0331,
                    lng=121.5653,
                ),
                {"id": "second-weather-test-user"},
            )

        self.assertEqual(cached, result)
        cached_user_limit.assert_not_called()
        cached_global_limit.assert_not_called()
        cached_http_client.assert_not_called()

    async def test_rejects_provider_error(self):
        provider_response = MagicMock(status_code=401)
        provider_context = self._provider_context(provider_response)

        with (
            patch.object(
                service_weather,
                "_require_open_weather_api_key",
                return_value="test-key",
            ),
            patch.object(
                service_weather,
                "get_weather_forecast_cache",
                return_value=None,
            ),
            patch.object(service_weather._weather_rate_limiter, "check"),
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
            ),
            patch.object(
                service_weather.httpx,
                "AsyncClient",
                return_value=provider_context,
            ),
        ):
            with self.assertRaises(HTTPException) as raised:
                await service_weather.weather_forecast(
                    service_weather.WeatherRequest(
                        lat=25.033,
                        lng=121.5654,
                    ),
                    {"id": "weather-test-user"},
                )

        self.assertEqual(raised.exception.status_code, 502)

    async def test_global_limit_does_not_call_provider(self):
        with (
            patch.object(
                service_weather,
                "_require_open_weather_api_key",
                return_value="test-key",
            ),
            patch.object(
                service_weather,
                "get_weather_forecast_cache",
                return_value=None,
            ),
            patch.object(service_weather._weather_rate_limiter, "check"),
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
                side_effect=HTTPException(
                    status_code=429,
                    detail="Too many requests",
                ),
            ),
            patch.object(
                service_weather.httpx,
                "AsyncClient",
            ) as http_client,
        ):
            with self.assertRaises(HTTPException) as raised:
                await service_weather.weather_forecast(
                    service_weather.WeatherRequest(
                        lat=25.033,
                        lng=121.5654,
                    ),
                    {"id": "weather-test-user"},
                )

        self.assertEqual(raised.exception.status_code, 429)
        http_client.assert_not_called()

    async def test_persistent_daily_cache_skips_provider(self):
        cached_forecast = {
            "forecast": [
                {
                    "date": "2026-08-16T00:00:00Z",
                    "main": "Clouds",
                    "description": "few clouds",
                    "icon": "02d",
                    "temp": 27.0,
                    "feels_like": 28.0,
                    "temp_min": 26.0,
                    "temp_max": 28.0,
                    "pressure": 1008,
                    "sea_level": 1008,
                    "grnd_level": 1005,
                }
            ],
            "expires_at": service_weather._next_location_midnight_utc(28800),
        }

        with (
            patch.object(
                service_weather._weather_rate_limiter,
                "check",
            ) as user_limit,
            patch.object(
                service_weather,
                "get_weather_forecast_cache",
                return_value=cached_forecast,
            ),
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
            ) as global_limit,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
            ) as http_client,
        ):
            result = await service_weather.weather_forecast(
                service_weather.WeatherRequest(
                    lat=25.033,
                    lng=121.5654,
                ),
                {"id": "weather-test-user"},
            )

        self.assertEqual(result.items[0].main, "Clouds")
        user_limit.assert_not_called()
        global_limit.assert_not_called()
        http_client.assert_not_called()

    async def test_concurrent_users_share_one_provider_request(self):
        provider_response = MagicMock(status_code=200)
        provider_response.json.return_value = {
            "city": {"timezone": 28800},
            "list": [
                {
                    "dt": 1786665600,
                    "weather": [
                        {
                            "main": "Clear",
                            "description": "clear sky",
                            "icon": "01d",
                        }
                    ],
                    "main": {
                        "temp": 28.5,
                        "feels_like": 30.0,
                        "temp_min": 27.0,
                        "temp_max": 29.0,
                        "pressure": 1008,
                    },
                }
            ],
        }
        provider_started = asyncio.Event()
        release_provider = asyncio.Event()

        async def delayed_provider_request(*args, **kwargs):
            provider_started.set()
            await release_provider.wait()
            return provider_response

        client = AsyncMock()
        client.get.side_effect = delayed_provider_request
        provider_context = MagicMock()
        provider_context.__aenter__ = AsyncMock(return_value=client)
        provider_context.__aexit__ = AsyncMock(return_value=None)

        with (
            patch.object(
                service_weather,
                "_require_open_weather_api_key",
                return_value="test-key",
            ),
            patch.object(
                service_weather,
                "get_weather_forecast_cache",
                return_value=None,
            ),
            patch.object(service_weather, "save_weather_forecast_cache"),
            patch.object(
                service_weather._weather_rate_limiter,
                "check",
            ) as user_limit,
            patch.object(
                service_weather._weather_global_rate_limiter,
                "check",
            ) as global_limit,
            patch.object(
                service_weather.httpx,
                "AsyncClient",
                return_value=provider_context,
            ),
        ):
            first_request = asyncio.create_task(
                service_weather.weather_forecast(
                    service_weather.WeatherRequest(
                        lat=25.033,
                        lng=121.5654,
                    ),
                    {"id": "first-user"},
                )
            )
            await provider_started.wait()
            second_request = asyncio.create_task(
                service_weather.weather_forecast(
                    service_weather.WeatherRequest(
                        lat=25.0331,
                        lng=121.5653,
                    ),
                    {"id": "second-user"},
                )
            )
            await asyncio.sleep(0)
            release_provider.set()
            first_result, second_result = await asyncio.gather(
                first_request,
                second_request,
            )

        self.assertEqual(first_result, second_result)
        client.get.assert_awaited_once()
        user_limit.assert_called_once_with("first-user")
        global_limit.assert_called_once_with("open_weather_forecast")

    def test_rejects_invalid_coordinates(self):
        with self.assertRaises(ValidationError):
            service_weather.WeatherRequest(lat=91, lng=121.5654)


if __name__ == "__main__":
    unittest.main()
