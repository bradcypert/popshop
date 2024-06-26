package pkg

import (
	"testing"
)

func TestRequestParserParsesSuccessfully(t *testing.T) {
	yaml := `---
request:
  path: "/users/1"
  verb: get
response:
  body: '{"id": 1, "name": "Brad"}'
  status: 200`

	want := ConfigTemplate{
		Request: RequestConfig{
			Path: "/users/1",
			Verb: "get",
		},
		Response: ResponseConfig{
			Body:   "{\"id\": 1, \"name\": \"Brad\"}",
			Status: 200,
		},
	}

	out, err := ParseConfigTemplate([]byte(yaml))
	if err != nil {
		t.Fatalf(`Received error when parsing proxy item: %v`, err)
	}
	if *out != want {
		t.Fatalf(`ParseProxyItem output did not match expectations:
      %q

      %q`, out, want)
	}
}

func TestRequestParserHandlesProxies(t *testing.T) {
	yaml := `---
request:
  path: "/users/1"
  verb: get
proxy: 
  url: https://raw.githubusercontent.com/PyreStudios/popshop/main/README.md
  verb: get`

	want := ConfigTemplate{
		Request: RequestConfig{
			Path: "/users/1",
			Verb: "get",
		},
		Proxy: ProxyConfig{
			URL:  "https://raw.githubusercontent.com/PyreStudios/popshop/main/README.md",
			Verb: "get",
		},
	}

	out, err := ParseConfigTemplate([]byte(yaml))
	if err != nil {
		t.Fatalf(`Received error when parsing proxy item: %v`, err)
	}
	if *out != want {
		t.Fatalf(`ParseProxyItem output did not match expectations:
      %q

      %q`, out, want)
	}
}
