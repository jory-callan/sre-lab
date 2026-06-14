kubectl exec -n redis-spotahome deployment/rfs-redisfailover-ha \
  -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

kubectl get endpoints -n redis-spotahome rfrm-redisfailover-ha

kubectl get pods -n redis-spotahome -l redisfailovers-role=master -o wide
