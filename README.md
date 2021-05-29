# Pop(up)Shop
## A replacement for that API that just isn't quite ready yet.

PopShop lets you define YAML files for incoming requests and responses.

```yml
---
request:
  path: "/users/1"
  verb: get
response:
  body: '{"id": 1, "name": "Brad"}'
  status: 200
```

PopShop parses these yaml files and spins up a simple HTTP server that, in this case, would return `{"id": 1, "name": "Brad"}` when you send a GET request to `/users/1`.

Eventually PopShop supports proxying to actual servers as well. This is useful in a scenario where you might originally use PopShop to mock several API endpoints,
but some of those eventually become available to leverage, but some may also still not be. This allows you to route all requests through PopShop and have it act as a proxy for certain requests, but still mock the responses that the underlying APIs might not be ready to handle.

```yml
---
request:
  path: "/readme"
  verb: get
proxy:
  url: https://raw.githubusercontent.com/PyreStudios/popshop/main/README.md
  verb: get
```
