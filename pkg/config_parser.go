package pkg

import (
	"gopkg.in/yaml.v3"
)

type Config struct {
	Port int `yaml:"port"`
}

func ParseYAML(config []byte) (*Config, error) {
	var c Config

	err := yaml.Unmarshal(config, &c)
	if err != nil {
		return nil, err
	}

	return &c, nil
}
