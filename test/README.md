### Testing

#### Integration Tests

These are run in the test image so we can easily manipulate configuration options.
They use both external resources (iprepd, redis) and mocks (fake backend, mock iprepd).

#### End to End Tests

These are run against the same image we deploy to prod as a quick sanity check.
The client is meant to run in a container so we can easily manipulate it's reputation in iprepd.
A separate backend container is used.
These tests are limited as it's not easy to manipulate configuration options and contain sleeps to avoid timing issues with caching.