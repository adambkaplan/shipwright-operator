package controllers

import (
	. "github.com/onsi/ginkgo/v2"

	"github.com/shipwright-io/operator/api/v1alpha1"
)

var _ = Describe("Install embedded build strategies", func() {

	var build *v1alpha1.ShipwrightBuild

	BeforeEach(func(ctx SpecContext) {
		setupTektonCRDs(ctx)
		build = createShipwrightBuild(ctx, "shipwright")
	})

	When("the install build strategies feature is enabled", func() {

		It("applies the embedded build strategy manifests to the cluster", func() {
			// expectedBuildStrategies := parseBuildStrategyNames()
			// for _, strategy := range expectedBuildStrategies {
			// 	strategyObj := &v1beta1.ClusterBuildStrategy{}
			// }

		})
	})

	AfterEach(func(ctx SpecContext) {
		deleteShipwrightBuild(ctx, build)
	})

})

func parseBuildStrategyNames() []string {
	return []string{"buildah", "buildpacks", "kaniko"}
}
