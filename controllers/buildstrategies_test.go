package controllers

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	k8syaml "k8s.io/apimachinery/pkg/util/yaml"

	"github.com/shipwright-io/build/pkg/apis/build/v1beta1"
	"github.com/shipwright-io/operator/api/v1alpha1"
	"github.com/shipwright-io/operator/pkg/common"
	"github.com/shipwright-io/operator/test"
)

var _ = Describe("Install embedded build strategies", func() {

	var build *v1alpha1.ShipwrightBuild

	BeforeEach(func(ctx SpecContext) {
		setupTektonCRDs(ctx)
		build = createShipwrightBuild(ctx, "shipwright")
		test.CRDEventuallyExists(ctx, k8sClient, "clusterbuildstrategies.shipwright.io")
	})

	When("the install build strategies feature is enabled", func() {

		It("applies the embedded build strategy manifests to the cluster", func(ctx SpecContext) {
			expectedBuildStrategies, err := parseBuildStrategyNames()
			Expect(err).NotTo(HaveOccurred())
			for _, strategy := range expectedBuildStrategies {
				strategyObj := &v1beta1.ClusterBuildStrategy{
					ObjectMeta: metav1.ObjectMeta{
						Name: strategy,
					},
				}
				By(fmt.Sprintf("checking for build strategy %q", strategy))
				test.EventuallyExists(ctx, k8sClient, strategyObj)
			}

		})
	})

	AfterEach(func(ctx SpecContext) {
		deleteShipwrightBuild(ctx, build)
	})

})

func parseBuildStrategyNames() ([]string, error) {
	koDataPath, err := common.KoDataPath()
	if err != nil {
		return nil, err
	}
	strategyPath := filepath.Join(koDataPath, "samples", "buildstrategy")
	sampleNames := []string{}
	err = filepath.WalkDir(strategyPath, func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() {
			return nil
		}
		clusterBuildStrategy := &v1beta1.ClusterBuildStrategy{}
		decodeErr := decodeYaml(path, clusterBuildStrategy)
		if decodeErr != nil {
			return decodeErr
		}
		sampleNames = append(sampleNames, clusterBuildStrategy.Name)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return sampleNames, nil
}

func decodeYaml(path string, obj *v1beta1.ClusterBuildStrategy) error {
	yaml, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	decoder := k8syaml.NewYAMLOrJSONDecoder(bytes.NewBuffer(yaml), 16)
	return decoder.Decode(obj)
}
