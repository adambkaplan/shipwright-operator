package buildstrategy

import (
	"context"
	"path/filepath"
	"testing"

	. "github.com/onsi/gomega"

	"github.com/shipwright-io/operator/pkg/common"
	crdv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	apiextensionsfake "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset/fake"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
)

func TestReconcileBuildStrategies(t *testing.T) {

	cases := []struct {
		name                  string
		installShipwrightCRDs bool
		expectRequeue         bool
	}{
		{
			name:                  "no Shipwright CRDs",
			installShipwrightCRDs: false,
			expectRequeue:         true,
		},
		{
			name:                  "install Shipwright CRDs",
			installShipwrightCRDs: true,
			expectRequeue:         false,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			o := NewWithT(t)
			ctx := context.Background()
			var cancel context.CancelFunc
			deadline, hasDeadline := t.Deadline()
			if hasDeadline {
				ctx, cancel = context.WithDeadline(context.Background(), deadline)
				defer cancel()
			}
			objects := []runtime.Object{}
			if tc.installShipwrightCRDs {
				objects = append(objects, &crdv1.CustomResourceDefinition{
					ObjectMeta: v1.ObjectMeta{
						Name: clusterBuildStrategiesCRD,
					},
				})
			}
			crdClient := apiextensionsfake.NewSimpleClientset(objects...)
			k8sClient := fake.NewClientBuilder().Build()
			log := zap.New()
			manifests, err := common.SetupManifestival(k8sClient, filepath.Join("samples", "buildstrategy"), log)
			o.Expect(err).NotTo(HaveOccurred(), "setting up Manifestival")
			requeue, err := ReconcileBuildStrategies(ctx, crdClient.ApiextensionsV1(), log, manifests)
			o.Expect(err).NotTo(HaveOccurred(), "reconciling build strategies")
			o.Expect(requeue).To(BeEquivalentTo(tc.expectRequeue), "check reconcile requeue")
		})
	}
}
