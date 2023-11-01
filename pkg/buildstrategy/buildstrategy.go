package buildstrategy

import (
	"context"

	"github.com/go-logr/logr"
	"github.com/manifestival/manifestival"
	crdclientv1 "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset/typed/apiextensions/v1"
)

func ReconcileBuildStrategies(ctx context.Context, crdClient crdclientv1.ApiextensionsV1Interface, log logr.Logger, manifest manifestival.Manifest) (bool, error) {
	return false, nil
}
