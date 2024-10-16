

%% resnet50
tag = 1;
refine50 = zeros(1,1000);
for i = 1:100:100000
    refine(tag) = ResNet50(i);
    tag = tag + 1;
end

%% resnet101
tag = 1;
refine101 = zeros(1,1000);
for i = 1:100:100000
    refine(tag) = ResNet101(i);
    tag = tag + 1;
end