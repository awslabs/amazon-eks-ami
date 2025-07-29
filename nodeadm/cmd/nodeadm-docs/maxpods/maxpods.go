package maxpods

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
	maxpods "github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet/maxpods"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type fileCmd struct {
	cmd *flaggy.Subcommand
}

func NewMaxPodsCommand() cli.Command {
	cmd := flaggy.NewSubcommand("max-pods")
	cmd.Description = "Show max pods values and limits on different instance types"
	return &fileCmd{
		cmd: cmd,
	}
}

func (c *fileCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *fileCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	ctx := context.Background()
	zap.L().Info("Getting instance type info")
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return err
	}
	instanceTypes, err := util.GetGlobalSortedInstanceTypeInfo(ctx, cfg)
	if err != nil {
		return err
	}
	writer := util.NewMarkdownWriter(os.Stdout)
	MemoryLimitMaxPodsFeatureGate := string(api.MemoryLimitMaxPods)
	header := []string{"Instance Type", "Classic Max Pods", "Classic Reserved (%)", "Prefix Deleg. Max Pods [1]", "Prefix Deleg. Reserved (%)", "AL2 Legacy Limit", "AL2 Legacy Limit Reserved (%)", fmt.Sprintf("%s Max Pods", MemoryLimitMaxPodsFeatureGate), fmt.Sprintf("%s Limit Reserved (%%)", MemoryLimitMaxPodsFeatureGate)}
	if err := writer.WriteHeader(header); err != nil {
		return err
	}

	for _, instanceTypeInfo := range instanceTypes {
		totalMB := uint64(instanceTypeInfo.MemoryMB)
		classicMaxPods := kubelet.GetClassicMaxPods(instanceTypeInfo.InstanceType, instanceTypeInfo.Region)
		classicReserved := maxpods.GetMemoryMebibytesToReserve(classicMaxPods)

		// naively calculate prefix delegation by multiplying the classic value by 16, excluding 2 host networking pods
		prefixDelegationMaxPods := ((classicMaxPods - 2) * 16) + 2
		prefixDelegationReserved := maxpods.GetMemoryMebibytesToReserve(prefixDelegationMaxPods)

		maxPodsLimit := maxpods.GetMaxPodsLimitForMemoryMiB(totalMB)
		limitedReserved := maxpods.GetMemoryMebibytesToReserve(maxPodsLimit)

		// Based on max-pods-calculator.sh provided with AL2, ref:
		// https://github.com/awslabs/amazon-eks-ami/blob/e541592913ed33413d813987dc4357b8e6160a59/templates/al2/runtime/max-pods-calculator.sh#L147-L160
		legacyMaxPodsLimit := 110
		if instanceTypeInfo.CPUCount > 30 {
			legacyMaxPodsLimit = 250
		}
		legacyLimitReserved := maxpods.GetMemoryMebibytesToReserve(int32(legacyMaxPodsLimit))

		row := []string{instanceTypeInfo.InstanceType, util.NumToStr(int(classicMaxPods)), util.Float64ToStr((float64(classicReserved) / float64(totalMB)) * 100), util.NumToStr(int(prefixDelegationMaxPods)), util.Float64ToStr((float64(prefixDelegationReserved) / float64(totalMB)) * 100), util.NumToStr(legacyMaxPodsLimit), util.Float64ToStr((float64(legacyLimitReserved) / float64(totalMB)) * 100), util.NumToStr(int(maxPodsLimit)), util.Float64ToStr((float64(limitedReserved) / float64(instanceTypeInfo.MemoryMB)) * 100)}
		if err := writer.Write(row); err != nil {
			return err
		}
	}
	fmt.Println("[1]: Max Pods for Prefix Delegation are naively calculated just using the fact that there are 16 * the number of available IPs, but this value can be untangibly high for some instance types")
	return nil
}
