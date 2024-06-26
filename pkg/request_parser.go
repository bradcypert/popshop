package pkg

import "gopkg.in/yaml.v3"

type RequestConfig struct {
	Path string `yaml:"path"`
	Verb string `yaml:"verb"`
}

type ResponseConfig struct {
	Body   string `yaml:"body"`
	Status int    `yaml:"status"`
}

type ProxyConfig struct {
	URL  string `yaml:"url"`
	Verb string `yaml:"verb"`
}

type ConfigTemplate struct {
	Request  RequestConfig  `yaml:"request"`
	Response ResponseConfig `yaml:"response"`
	Proxy    ProxyConfig    `yaml:"proxy"`
}

func ParseConfigTemplate(config []byte) (*ConfigTemplate, error) {
	var c ConfigTemplate

	err := yaml.Unmarshal(config, &c)
	if err != nil {
		return nil, err
	}

	return &c, nil

}
