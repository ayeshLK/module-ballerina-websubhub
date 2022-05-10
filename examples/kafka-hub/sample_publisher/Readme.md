# Sample Publisher #

This ballerina project contains a sample to describer `websubhub:PublisherClient`.

## Prerequisites $
- Ballerina Distribution 2201.0.3

## How to Build #
- Update `HUB_URL` configuration found in `Config.toml`.

- Update `repository` in `Cloud.toml` (point to your ACR).

- Run following command.
```sh
bal build
```
- Find the k8s artifacts in `target/kubernetes/samplePublisher/samplePublisher.yaml`.

