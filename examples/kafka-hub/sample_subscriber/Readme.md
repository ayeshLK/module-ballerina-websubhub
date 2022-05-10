# Sample Subscriber #

This ballerina project contains a sample to describer `websub:SubscriberService`.

## Prerequisites $
- Ballerina Distribution 2201.0.3

## How to Build #
- Update `HUB_URL` configuration found in `Config.toml`.

- Update `CALLBACK` configuration found in `Config.toml`.

- Update `repository` in `Cloud.toml` (point to your ACR).

- Run following command.
```sh
bal build
```

- Find the k8s artifacts in `target/kubernetes/sampleSubscriber/sampleSubscriber.yaml`.

- In addition to generated artifaccts another required k8s artifacts could be found in `k8s` directory.
